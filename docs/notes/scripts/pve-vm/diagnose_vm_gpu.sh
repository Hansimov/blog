#!/usr/bin/env bash

set -Eeuo pipefail

VMID=101
GUEST_BDF=""
QM_TIMEOUT="${QM_TIMEOUT:-30}"
LSPCI_TIMEOUT="${LSPCI_TIMEOUT:-3}"

log() {
	printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
	printf '[%s] ERROR: %s\n' "$(date '+%F %T')" "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  diagnose_vm_gpu.sh [VMID] GUEST_BDF

Example:
  diagnose_vm_gpu.sh 101 0000:06:00.0

The script is read-only. It maps a guest PCI endpoint from the live QEMU
"info pci" topology to the corresponding PVE hostpci key and host BDF, then
prints the host endpoint, DMI slot, sysfs path and upstream PCIe link/error
status. Do not infer this mapping from hostpci numbering: guest bus numbering
can change whenever hostpci entries are compacted or reordered.
EOF
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

normalize_guest_endpoint() {
	local raw="${1%%,*}"

	raw="${raw,,}"
	if [[ "$raw" =~ ^[0-9a-f]{8}:([0-9a-f]{2}:[0-9a-f]{2}(\.[0-7])?)$ ]]; then
		raw="${BASH_REMATCH[1]}"
	fi
	if [[ "$raw" =~ ^[0-9a-f]{2}:[0-9a-f]{2}$ ]]; then
		raw="${raw}.0"
	fi
	if [[ "$raw" =~ ^[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$ ]]; then
		raw="0000:${raw}"
	fi
	if [[ "$raw" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}$ ]]; then
		raw="${raw}.0"
	fi

	[[ "$raw" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]$ ]] || return 1
	printf '%s\n' "$raw"
}

normalize_host_base() {
	local raw="${1%%,*}"

	raw="${raw,,}"
	if [[ "$raw" =~ ^[0-9a-f]{2}:[0-9a-f]{2}(\.[0-7])?$ ]]; then
		raw="0000:${raw}"
	fi
	if [[ "$raw" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}(\.[0-7])?$ ]]; then
		printf '%s\n' "${raw%.*}"
		return 0
	fi
	return 1
}

parse_args() {
	if [[ $# -gt 0 && "$1" != --* && "$1" =~ ^[1-9][0-9]*$ ]]; then
		VMID="$1"
		shift
	fi

	while [[ $# -gt 0 ]]; do
		case "$1" in
			-h|--help)
				usage
				exit 0
				;;
			--guest-bdf)
				[[ $# -ge 2 ]] || die "--guest-bdf requires a BDF"
				GUEST_BDF="$2"
				shift 2
				;;
			--*)
				die "unknown argument: $1"
				;;
			*)
				[[ -z "$GUEST_BDF" ]] || die "unexpected extra argument: $1"
				GUEST_BDF="$1"
				shift
				;;
		esac
	done
}

map_guest_to_qemu_id() {
	local monitor_output="$1"
	local guest_endpoint="$2"
	local rest="${guest_endpoint#*:}"
	local bus_hex="${rest%%:*}"
	local devfunc="${rest#*:}"
	local dev_hex="${devfunc%%.*}"
	local function_dec="${devfunc##*.}"
	local bus_dec=$((16#${bus_hex}))
	local device_dec=$((16#${dev_hex}))
	local in_target=0
	local line

	while IFS= read -r line; do
		if [[ "$line" =~ Bus[[:space:]]+([0-9]+),[[:space:]]+device[[:space:]]+([0-9]+),[[:space:]]+function[[:space:]]+([0-9]+): ]]; then
			if ((10#${BASH_REMATCH[1]} == bus_dec &&
				10#${BASH_REMATCH[2]} == device_dec &&
				10#${BASH_REMATCH[3]} == function_dec)); then
				in_target=1
			else
				in_target=0
			fi
			continue
		fi
		if [[ "$in_target" -eq 1 && "$line" =~ id[[:space:]]+\"(hostpci[0-9]+\.[0-7])\" ]]; then
			printf '%s\n' "${BASH_REMATCH[1]}"
			return 0
		fi
	done <<<"$monitor_output"

	return 1
}

dmi_slot_for_endpoint() {
	local endpoint="$1"

	dmidecode -t slot 2>/dev/null | awk -v target="$endpoint" '
		BEGIN { RS = ""; FS = "\n"; IGNORECASE = 1 }
		{
			designation = ""
			bus = ""
			for (i = 1; i <= NF; i++) {
				if ($i ~ /^[[:space:]]*Designation:/) {
					designation = $i
					sub(/^[[:space:]]*Designation:[[:space:]]*/, "", designation)
				}
				if ($i ~ /^[[:space:]]*Bus Address:/) {
					bus = $i
					sub(/^[[:space:]]*Bus Address:[[:space:]]*/, "", bus)
				}
			}
			if (tolower(bus) == tolower(target)) {
				print designation
				exit
			}
		}
	'
}

print_upstream_diagnostics() {
	local sysfs_path="$1"
	local endpoint="$2"
	local bdf
	local details
	local -a path_bdfs=()

	mapfile -t path_bdfs < <(grep -oE '0000:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' <<<"$sysfs_path")
	((${#path_bdfs[@]} > 1)) || {
		printf 'upstream_status=unavailable\n'
		return 0
	}

	printf '%s\n' 'upstream_bridges:'
	for bdf in "${path_bdfs[@]:0:${#path_bdfs[@]}-1}"; do
		printf '  [%s] %s\n' "$bdf" "$(timeout "$LSPCI_TIMEOUT" lspci -Dnn -s "$bdf" 2>/dev/null || true)"
		details="$(timeout "$LSPCI_TIMEOUT" lspci -Dvv -s "$bdf" 2>/dev/null || true)"
		grep -E 'Physical Slot|DevSta:|LnkCap:|LnkSta:|LnkSta2:|UESta:|CESta:|RootSta:' <<<"$details" |
			sed 's/^/    /' || true
	done

	# Keep the endpoint parameter visible in shell traces and make accidental
	# calls with a mismatched path easier to spot during review.
	[[ "${path_bdfs[-1]}" == "$endpoint" ]] ||
		log "WARN: sysfs path ends at ${path_bdfs[-1]}, expected ${endpoint}"
}

main() {
	local guest_endpoint
	local pve_node
	local monitor_output
	local qemu_id
	local hostpci_key
	local hostpci_value
	local host_base
	local host_endpoint
	local config_vendor
	local sysfs_path
	local physical_slot
	local numa_node="unknown"
	local iommu_group="unknown"
	local status

	parse_args "$@"
	[[ "$VMID" =~ ^[1-9][0-9]*$ ]] || die "invalid VMID: ${VMID}"
	[[ -n "$GUEST_BDF" ]] || {
		usage >&2
		exit 1
	}
	guest_endpoint="$(normalize_guest_endpoint "$GUEST_BDF" || true)"
	[[ -n "$guest_endpoint" ]] || die "invalid guest BDF: ${GUEST_BDF}"

	[[ $EUID -eq 0 ]] || die "this script must run as root on the PVE host"
	require_cmd qm
	require_cmd pvesh
	require_cmd hostname
	require_cmd timeout
	require_cmd lspci
	require_cmd setpci
	require_cmd dmidecode
	[[ -f "/etc/pve/qemu-server/${VMID}.conf" ]] ||
		die "VM config not found for VM ${VMID}"

	status="$(timeout "$QM_TIMEOUT" qm status "$VMID" 2>/dev/null | awk '{print $2}')"
	[[ "$status" == running ]] || die "VM ${VMID} must be running to inspect its live QEMU topology"
	pve_node="$(hostname)"
	monitor_output="$(timeout "$QM_TIMEOUT" pvesh create \
		"/nodes/${pve_node}/qemu/${VMID}/monitor" \
		--command 'info pci' 2>/dev/null | tr -d '\r')" ||
		die "failed to read QEMU info pci for VM ${VMID}"
	qemu_id="$(map_guest_to_qemu_id "$monitor_output" "$guest_endpoint" || true)"
	[[ -n "$qemu_id" ]] ||
		die "guest endpoint ${guest_endpoint} was not mapped to a hostpci device in live QEMU"

	hostpci_key="${qemu_id%%.*}"
	hostpci_value="$(qm config "$VMID" | awk -F': ' -v key="$hostpci_key" '$1 == key { print $2; exit }')"
	[[ -n "$hostpci_value" ]] || die "${hostpci_key} is absent from VM ${VMID} config"
	host_base="$(normalize_host_base "$hostpci_value" || true)"
	[[ -n "$host_base" ]] || die "${hostpci_key} does not contain a direct host BDF: ${hostpci_value}"
	host_endpoint="${host_base}.0"
	config_vendor="$(timeout "$LSPCI_TIMEOUT" setpci -s "$host_endpoint" VENDOR_ID.w 2>/dev/null || true)"
	config_vendor="${config_vendor,,}"
	sysfs_path="$(readlink -f "/sys/bus/pci/devices/${host_endpoint}" 2>/dev/null || true)"
	physical_slot="$(dmi_slot_for_endpoint "$host_endpoint" || true)"
	if [[ -r "/sys/bus/pci/devices/${host_endpoint}/numa_node" ]]; then
		numa_node="$(<"/sys/bus/pci/devices/${host_endpoint}/numa_node")"
	fi
	if [[ -e "/sys/bus/pci/devices/${host_endpoint}/iommu_group" ]]; then
		iommu_group="$(basename "$(readlink -f "/sys/bus/pci/devices/${host_endpoint}/iommu_group")")"
	fi

	printf 'vmid=%s\n' "$VMID"
	printf 'guest_bdf=%s\n' "$guest_endpoint"
	printf 'qemu_id=%s\n' "$qemu_id"
	printf 'hostpci_key=%s\n' "$hostpci_key"
	printf 'hostpci_value=%s\n' "$hostpci_value"
	printf 'host_bdf=%s\n' "$host_base"
	printf 'host_endpoint=%s\n' "$host_endpoint"
	printf 'host_config_vendor=%s\n' "${config_vendor:-no-response}"
	printf 'physical_slot=%s\n' "${physical_slot:-unknown}"
	printf 'numa_node=%s\n' "$numa_node"
	printf 'iommu_group=%s\n' "$iommu_group"
	printf 'sysfs_path=%s\n' "${sysfs_path:-absent}"
	printf 'cached_endpoint_identity=%s\n' \
		"$(timeout "$LSPCI_TIMEOUT" lspci -Dnn -s "$host_endpoint" 2>/dev/null || true)"

	if [[ "$config_vendor" == ffff || -z "$config_vendor" ]]; then
		printf 'endpoint_health=unresponsive\n'
	else
		printf 'endpoint_health=config-space-responding\n'
	fi
	[[ -n "$sysfs_path" ]] && print_upstream_diagnostics "$sysfs_path" "$host_endpoint"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi
