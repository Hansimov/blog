#!/usr/bin/env bash

set -Eeuo pipefail

VMID=101
MODE="apply"
ONLY_SET=0
ONLY_CSV=""
INCLUDE_QUARANTINED=0
VFIO_PROBE=1
QUARANTINE_BDF=""
QUARANTINE_REASON="manual quarantine"
UNQUARANTINE_BDF=""

STATE_DIR="${STATE_DIR:-/root/.vm-gpu-state}"
BACKUP_DIR="${BACKUP_DIR:-/root/.vm-start-backups}"
LSPCI_TIMEOUT="${LSPCI_TIMEOUT:-3}"
QM_TIMEOUT="${QM_TIMEOUT:-30}"
MAX_HOSTPCI_DEVICES="${MAX_HOSTPCI_DEVICES:-16}"
GPU_VENDOR_ID="${GPU_VENDOR_ID:-10de}"
ALLOW_NON_VFIO="${ALLOW_NON_VFIO:-0}"
QEMU_BIN="${QEMU_BIN:-/usr/bin/kvm}"
VFIO_PROBE_SECONDS="${VFIO_PROBE_SECONDS:-5}"
MAX_VFIO_PROBES="${MAX_VFIO_PROBES:-20}"

CONF=""
QUARANTINE_FILE=""
PROBE_DIR=""
CONFIG_LOCK_FILE=""
rollback_needed=0
backup_file=""
vfio_probe_count=0
VERIFY_REASON=""

declare -a visible_gpus=()
declare -a requested_gpus=()
declare -a selected_gpus=()
declare -a skipped_gpus=()
declare -a compatible_gpus=()
declare -a combination_excluded_gpus=()
declare -a current_keys=()
declare -a original_keys=()
declare -A current_values=()
declare -A current_by_bdf=()
declare -A original_values=()
declare -A skip_reasons=()
declare -A gpu_warnings=()

log() {
	printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

warn() {
	printf '[%s] WARN: %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
	printf '[%s] ERROR: %s\n' "$(date '+%F %T')" "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  qm_gpus.sh [VMID] [--apply|--dry-run|--list]
                         [--only BDF[,BDF...]]
                         [--include-quarantined]
                         [--vfio-probe|--no-vfio-probe]
  qm_gpus.sh [VMID] --quarantine BDF [--reason TEXT]
  qm_gpus.sh [VMID] --unquarantine BDF

Modes:
  --apply       Discover healthy GPUs and replace hostpci entries with a
                contiguous hostpci0..N configuration. This is the default.
  --dry-run     Print the desired contiguous configuration without changing it.
  --list        Print only selected base BDFs, one per line.

Quarantined GPUs are excluded by default. --include-quarantined temporarily
includes them in selection and probing but never clears quarantine records.
Use start_vm101.sh --revalidate-quarantined for verified recovery and promotion.

Apply mode uses a small 256 MiB QEMU/VFIO realization probe by default. It
validates the whole candidate set without booting the large production VM and
uses the same lightweight probe for binary isolation if realization fails.
EOF
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

normalize_bdf() {
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

contains_bdf() {
	local needle="$1"
	shift
	local item

	for item in "$@"; do
		[[ "$item" == "$needle" ]] && return 0
	done
	return 1
}

join_csv() {
	local IFS=','
	printf '%s' "$*"
}

vm_status() {
	local output

	if output="$(timeout "$QM_TIMEOUT" perl -MPVE::QemuServer::Helpers -e '
		my $vmid = shift;
		print PVE::QemuServer::Helpers::vm_running_locally($vmid)
			? "running\n" : "stopped\n";
	' "$VMID" 2>/dev/null)"; then
		printf '%s\n' "$output"
		return 0
	fi
	output="$(timeout "$QM_TIMEOUT" qm status "$VMID" 2>/dev/null)" || return 1
	awk '{print $2}' <<<"$output"
}

discover_visible_gpus() {
	local output
	local line
	local bdf
	local base
	local -a found=()

	output="$(timeout "$LSPCI_TIMEOUT" lspci -Dnn 2>/dev/null)" ||
		die "lspci failed or timed out while discovering GPUs"

	while IFS= read -r line; do
		[[ "$line" == *"[${GPU_VENDOR_ID}:"* ]] || continue
		[[ "$line" =~ VGA\ compatible\ controller|3D\ controller|Display\ controller ]] || continue
		bdf="${line%% *}"
		base="$(normalize_bdf "$bdf" || true)"
		[[ -n "$base" ]] || continue
		contains_bdf "$base" "${found[@]}" || found+=("$base")
	done <<<"$output"

	if [[ ${#found[@]} -gt 0 ]]; then
		printf '%s\n' "${found[@]}" | sort -V
	fi
}

quarantine_reason() {
	local bdf="$1"

	[[ -f "$QUARANTINE_FILE" ]] || return 1
	awk -v target="$bdf" '
		$0 !~ /^[[:space:]]*(#|$)/ && $1 == target {
			$1 = ""
			sub(/^[[:space:]]+/, "")
			print
			found = 1
			exit
		}
		END { if (!found) exit 1 }
	' "$QUARANTINE_FILE"
}

quarantine_gpu() {
	local bdf="$1"
	local reason="$2"
	local tmp

	reason="${reason//$'\t'/ }"
	reason="${reason//$'\n'/ }"
	mkdir -p -m 700 "$STATE_DIR"
	touch "$QUARANTINE_FILE"
	chmod 600 "$QUARANTINE_FILE"
	exec 8>"${STATE_DIR}/vm${VMID}.lock"
	flock 8

	tmp="$(mktemp "${STATE_DIR}/vm${VMID}.quarantine.XXXXXX")"
	awk -v target="$bdf" '
		$0 ~ /^[[:space:]]*(#|$)/ || $1 != target { print }
	' "$QUARANTINE_FILE" >"$tmp"
	printf '%s\t%s\t%s\n' "$bdf" "$(date -Is)" "$reason" >>"$tmp"
	install -m 600 "$tmp" "$QUARANTINE_FILE"
	rm -f "$tmp"
	log "Quarantined ${bdf}: ${reason}"
}

unquarantine_gpu() {
	local bdf="$1"
	local tmp

	[[ -f "$QUARANTINE_FILE" ]] || {
		log "No quarantine state exists for VM ${VMID}"
		return 0
	}

	exec 8>"${STATE_DIR}/vm${VMID}.lock"
	flock 8
	tmp="$(mktemp "${STATE_DIR}/vm${VMID}.quarantine.XXXXXX")"
	awk -v target="$bdf" '
		$0 ~ /^[[:space:]]*(#|$)/ || $1 != target { print }
	' "$QUARANTINE_FILE" >"$tmp"
	install -m 600 "$tmp" "$QUARANTINE_FILE"
	rm -f "$tmp"
	log "Removed ${bdf} from VM ${VMID} quarantine"
}

assigned_to_other_vm() {
	local bdf="$1"
	local config
	local other_vmid
	local line
	local value
	local other_bdf

	for config in /etc/pve/qemu-server/*.conf; do
		[[ -e "$config" ]] || continue
		other_vmid="${config##*/}"
		other_vmid="${other_vmid%.conf}"
		[[ "$other_vmid" == "$VMID" ]] && continue

		while IFS= read -r line; do
			[[ "$line" =~ ^hostpci[0-9]+:[[:space:]]*(.+)$ ]] || continue
			value="${BASH_REMATCH[1]}"
			other_bdf="$(normalize_bdf "$value" || true)"
			[[ "$other_bdf" == "$bdf" ]] && return 0
		done < <(awk '/^\[/ { exit } { print }' "$config")
	done

	return 1
}

HEALTH_REASON=""
HEALTH_WARNING=""

gpu_is_healthy() {
	local bdf="$1"
	local endpoint="${bdf}.0"
	local sysfs="/sys/bus/pci/devices/${endpoint}"
	local vendor
	local class
	local config_vendor
	local details
	local link_line
	local driver=""
	local width

	HEALTH_REASON=""
	HEALTH_WARNING=""

	[[ -d "$sysfs" ]] || {
		HEALTH_REASON="PCI endpoint is absent"
		return 1
	}

	vendor="$(<"${sysfs}/vendor")"
	class="$(<"${sysfs}/class")"
	[[ "${vendor,,}" == "0x${GPU_VENDOR_ID}" ]] || {
		HEALTH_REASON="unexpected vendor ${vendor}"
		return 1
	}
	[[ "$class" == 0x03* ]] || {
		HEALTH_REASON="endpoint class ${class} is not a display controller"
		return 1
	}

	config_vendor="$(timeout "$LSPCI_TIMEOUT" setpci -s "$endpoint" VENDOR_ID.w 2>/dev/null || true)"
	config_vendor="${config_vendor,,}"
	[[ "$config_vendor" == "$GPU_VENDOR_ID" ]] || {
		HEALTH_REASON="PCI config space is unreadable (${config_vendor:-no response})"
		return 1
	}

	details="$(timeout "$LSPCI_TIMEOUT" lspci -Dvv -s "$endpoint" 2>/dev/null || true)"
	[[ -n "$details" ]] || {
		HEALTH_REASON="lspci detail read failed"
		return 1
	}

	if grep -Eq 'DevSta:.*FatalErr\+|UESta:.*SDES\+' <<<"$details"; then
		HEALTH_REASON="fatal or Surprise Down status is asserted"
		return 1
	fi

	link_line="$(awk '/LnkSta:/ { print; exit }' <<<"$details")"
	if [[ "$link_line" =~ Width[[:space:]]+x([0-9]+) ]]; then
		width="${BASH_REMATCH[1]}"
		((width > 0)) || {
			HEALTH_REASON="PCIe link width is x0"
			return 1
		}
	else
		HEALTH_REASON="PCIe link status is unavailable"
		return 1
	fi

	[[ -e "${sysfs}/iommu_group" ]] || {
		HEALTH_REASON="IOMMU group is unavailable"
		return 1
	}

	if [[ -L "${sysfs}/driver" ]]; then
		driver="$(basename "$(readlink -f "${sysfs}/driver")")"
	fi
	if [[ -n "$driver" && "$driver" != "vfio-pci" && "$ALLOW_NON_VFIO" != "1" ]]; then
		HEALTH_REASON="function 0 is bound to ${driver}, not vfio-pci"
		return 1
	fi

	if grep -Eq 'CESta:.*(RxErr|BadTLP|BadDLLP|Rollover|Timeout|AdvNonFatalErr)\+' <<<"$details"; then
		HEALTH_WARNING="sticky correctable PCIe status is present"
	fi

	return 0
}

parse_requested_gpus() {
	local item
	local base
	local key
	local -a raw=()

	if [[ "$ONLY_SET" -eq 0 ]]; then
		for key in "${current_keys[@]}"; do
			base="$(normalize_bdf "${current_values[$key]}" || true)"
			[[ -n "$base" ]] || continue
			contains_bdf "$base" "${requested_gpus[@]}" || requested_gpus+=("$base")
		done
		for base in "${visible_gpus[@]}"; do
			contains_bdf "$base" "${requested_gpus[@]}" || requested_gpus+=("$base")
		done
		return 0
	fi

	[[ -z "$ONLY_CSV" || "$ONLY_CSV" == "none" ]] && {
		requested_gpus=()
		return 0
	}

	IFS=',' read -r -a raw <<<"$ONLY_CSV"
	for item in "${raw[@]}"; do
		base="$(normalize_bdf "$item" || true)"
		[[ -n "$base" ]] || die "invalid GPU BDF in --only: ${item}"
		contains_bdf "$base" "${requested_gpus[@]}" || requested_gpus+=("$base")
	done
}

select_gpus() {
	local bdf
	local reason

	mapfile -t visible_gpus < <(discover_visible_gpus)
	parse_requested_gpus

	for bdf in "${requested_gpus[@]}"; do
		if ! contains_bdf "$bdf" "${visible_gpus[@]}"; then
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="not visible in the current host PCI inventory"
			continue
		fi

		if [[ "$INCLUDE_QUARANTINED" -eq 0 ]] && reason="$(quarantine_reason "$bdf" 2>/dev/null)"; then
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="quarantined: ${reason}"
			continue
		fi

		if assigned_to_other_vm "$bdf"; then
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="assigned to another VM"
			continue
		fi

		if gpu_is_healthy "$bdf"; then
			selected_gpus+=("$bdf")
			[[ -n "$HEALTH_WARNING" ]] && gpu_warnings["$bdf"]="$HEALTH_WARNING"
		else
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="$HEALTH_REASON"
		fi
	done

	if [[ "$ONLY_SET" -eq 1 && ${#skipped_gpus[@]} -gt 0 ]]; then
		for bdf in "${skipped_gpus[@]}"; do
			warn "Requested GPU ${bdf} rejected: ${skip_reasons[$bdf]}"
		done
		return 1
	fi
}

prepare_vfio_gpu() {
	local bdf="$1"
	local function_path
	local function_bdf
	local driver=""
	local -a function_paths=()

	shopt -s nullglob
	function_paths=(/sys/bus/pci/devices/"${bdf}".*)
	shopt -u nullglob
	[[ ${#function_paths[@]} -gt 0 ]] || return 1

	for function_path in "${function_paths[@]}"; do
		function_bdf="${function_path##*/}"
		driver=""
		if [[ -L "${function_path}/driver" ]]; then
			driver="$(basename "$(readlink -f "${function_path}/driver")")"
		fi
		[[ "$driver" == "vfio-pci" ]] && continue

		printf 'vfio-pci' >"${function_path}/driver_override" || return 1
		if [[ -n "$driver" ]]; then
			printf '%s' "$function_bdf" >"${function_path}/driver/unbind" || return 1
		fi
		printf '%s' "$function_bdf" >/sys/bus/pci/drivers_probe || return 1

		if [[ ! -L "${function_path}/driver" ]] ||
			[[ "$(basename "$(readlink -f "${function_path}/driver")")" != "vfio-pci" ]]; then
			return 1
		fi
	done
}

prepare_selected_gpus_for_vfio() {
	local bdf
	local -a prepared=()

	modprobe vfio-pci
	for bdf in "${selected_gpus[@]}"; do
		if prepare_vfio_gpu "$bdf"; then
			prepared+=("$bdf")
		else
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="could not bind every PCI function to vfio-pci"
		fi
	done
	selected_gpus=("${prepared[@]}")
}

vfio_probe_subset() {
	local label="$1"
	shift
	local -a subset=("$@")
	local -a command=()
	local -a function_paths=()
	local bdf
	local function_path
	local function_bdf
	local function_number
	local root_port
	local root_addr
	local device_arg
	local index
	local rc=0
	local log_file
	local safe_label="${label//[^a-zA-Z0-9_.-]/_}"

	vfio_probe_count=$((vfio_probe_count + 1))
	((vfio_probe_count <= MAX_VFIO_PROBES)) ||
		die "reached lightweight VFIO probe limit ${MAX_VFIO_PROBES}"

	log_file="${PROBE_DIR}/$(printf '%02d' "$vfio_probe_count")-${safe_label}.log"
	command=(
		"$QEMU_BIN"
		-name "vm${VMID}-vfio-probe"
		-machine "q35,accel=kvm"
		-cpu host
		-m 256M
		-nodefaults
		-display none
		-serial none
		-monitor none
		-no-reboot
		-S
	)

	for index in "${!subset[@]}"; do
		bdf="${subset[$index]}"
		root_port="rp${index}"
		printf -v root_addr '0x%x' "$((index + 2))"
		command+=(
			-device "pcie-root-port,id=${root_port},bus=pcie.0,addr=${root_addr},chassis=$((index + 1))"
		)

		shopt -s nullglob
		function_paths=(/sys/bus/pci/devices/"${bdf}".*)
		shopt -u nullglob
		mapfile -t function_paths < <(printf '%s\n' "${function_paths[@]}" | sort -V)

		for function_path in "${function_paths[@]}"; do
			function_bdf="${function_path##*/}"
			function_number="${function_bdf##*.}"
			device_arg="vfio-pci,host=${function_bdf},id=gpu${index}f${function_number},bus=${root_port},addr=0x0.${function_number}"
			if [[ "$function_number" == "0" && ${#function_paths[@]} -gt 1 ]]; then
				device_arg+=",multifunction=on"
			fi
			command+=(-device "$device_arg")
		done
	done

	log "Lightweight VFIO probe ${vfio_probe_count}: ${label} (${#subset[@]} GPUs, 256 MiB)"
	if timeout --foreground --signal=TERM --kill-after=2 "$VFIO_PROBE_SECONDS" \
		"${command[@]}" >"$log_file" 2>&1; then
		rc=0
	else
		rc=$?
	fi

	if [[ "$rc" -ne 124 ]]; then
		warn "Lightweight VFIO probe failed: ${label} (rc=${rc}, log=${log_file})"
		sed -n '1,100p' "$log_file" | sed 's/^/  /' >&2 || true
		return 1
	fi

	for bdf in "${subset[@]}"; do
		if ! gpu_is_healthy "$bdf"; then
			warn "Post-probe health check failed for ${bdf}: ${HEALTH_REASON}"
			return 1
		fi
	done
	return 0
}

remove_bdf_from_list() {
	local target="$1"
	shift
	local item

	for item in "$@"; do
		[[ "$item" == "$target" ]] || printf '%s\n' "$item"
	done
}

VFIO_FOUND_BAD=""

find_one_vfio_failure() {
	local -a suspects=("$@")
	local -a first_half=()
	local -a second_half=()
	local split
	local candidate

	VFIO_FOUND_BAD=""
	while [[ ${#suspects[@]} -gt 1 ]]; do
		split=$(( (${#suspects[@]} + 1) / 2 ))
		first_half=("${suspects[@]:0:split}")
		second_half=("${suspects[@]:split}")

		if vfio_probe_subset "bisect-${#first_half[@]}-of-${#suspects[@]}" "${first_half[@]}"; then
			suspects=("${second_half[@]}")
		else
			suspects=("${first_half[@]}")
		fi
	done

	[[ ${#suspects[@]} -eq 1 ]] || return 2
	candidate="${suspects[0]}"
	if vfio_probe_subset "confirm-${candidate//:/-}" "$candidate"; then
		return 2
	fi

	VFIO_FOUND_BAD="$candidate"
}

vfio_greedy_compatible_set() {
	local bdf
	local -a trial=()

	compatible_gpus=()
	combination_excluded_gpus=()
	for bdf in "${selected_gpus[@]}"; do
		trial=("${compatible_gpus[@]}" "$bdf")
		if vfio_probe_subset "greedy-${#trial[@]}" "${trial[@]}"; then
			compatible_gpus=("${trial[@]}")
			continue
		fi

		if [[ ${#compatible_gpus[@]} -eq 0 ]] ||
			! vfio_probe_subset "greedy-single-${bdf//:/-}" "$bdf"; then
			quarantine_gpu "$bdf" "confirmed singleton lightweight VFIO probe failure"
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="quarantined after singleton VFIO probe failure"
		else
			combination_excluded_gpus+=("$bdf")
			skipped_gpus+=("$bdf")
			skip_reasons["$bdf"]="excluded for this run after combination-only VFIO failure"
		fi
	done
	selected_gpus=("${compatible_gpus[@]}")
}

run_vfio_diagnostics() {
	local -a remaining=()

	[[ -x "$QEMU_BIN" ]] || die "QEMU binary is not executable: ${QEMU_BIN}"
	mkdir -p -m 700 "$STATE_DIR" "${STATE_DIR}/probes"
	chmod 700 "$STATE_DIR" "${STATE_DIR}/probes"
	PROBE_DIR="${STATE_DIR}/probes/vm${VMID}-$(date '+%F-%H%M%S-%N')"
	mkdir -m 700 "$PROBE_DIR"

	prepare_selected_gpus_for_vfio
	remaining=("${selected_gpus[@]}")
	if [[ ${#remaining[@]} -eq 0 ]]; then
		log "No GPU candidates remain after static and VFIO binding checks"
		return 0
	fi

	if vfio_probe_subset "combined-all" "${remaining[@]}"; then
		log "All ${#remaining[@]} candidates passed the lightweight combined VFIO probe"
		return 0
	fi

	if ! vfio_probe_subset "baseline-no-device"; then
		die "lightweight QEMU baseline failed without PCI devices; refusing to quarantine GPUs"
	fi

	while [[ ${#remaining[@]} -gt 0 ]]; do
		if find_one_vfio_failure "${remaining[@]}"; then
			quarantine_gpu "$VFIO_FOUND_BAD" "confirmed singleton lightweight VFIO probe failure"
			skipped_gpus+=("$VFIO_FOUND_BAD")
			skip_reasons["$VFIO_FOUND_BAD"]="quarantined after singleton VFIO probe failure"
			mapfile -t remaining < <(
				remove_bdf_from_list "$VFIO_FOUND_BAD" "${remaining[@]}"
			)
			if vfio_probe_subset "combined-after-quarantine" "${remaining[@]}"; then
				selected_gpus=("${remaining[@]}")
				return 0
			fi
			continue
		fi

		warn "VFIO failure is combination-dependent; finding the largest compatible ordered set"
		selected_gpus=("${remaining[@]}")
		vfio_greedy_compatible_set
		return 0
	done

	selected_gpus=()
}

load_current_hostpci() {
	local line
	local key
	local value
	local bdf

	current_keys=()
	current_values=()
	current_by_bdf=()

	while IFS= read -r line; do
		[[ "$line" =~ ^(hostpci[0-9]+):[[:space:]]*(.+)$ ]] || continue
		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		current_keys+=("$key")
		current_values["$key"]="$value"
		bdf="$(normalize_bdf "$value" || true)"
		[[ -n "$bdf" ]] && current_by_bdf["$bdf"]="$value"
	done < <(qm config "$VMID")
}

value_for_gpu() {
	local bdf="$1"
	local value="${current_by_bdf[$bdf]:-}"

	if [[ -z "$value" ]]; then
		printf '%s,pcie=1\n' "$bdf"
		return 0
	fi

	if [[ "$value" != *",pcie="* ]]; then
		value="${value},pcie=1"
	fi
	printf '%s\n' "$value"
}

restore_original_config() {
	local key
	local -a active_keys=()
	local -a delete_keys=()
	local -a command=(timeout "$QM_TIMEOUT" qm set "$VMID")
	local -A original_key_set=()

	rollback_needed=0
	warn "Restoring original hostpci configuration for VM ${VMID}"
	mapfile -t active_keys < <(
		qm config "$VMID" | awk -F: '/^hostpci[0-9]+:/ { print $1 }'
	)
	for key in "${original_keys[@]}"; do
		original_key_set["$key"]=1
	done
	for key in "${active_keys[@]}"; do
		[[ -n "${original_key_set[$key]:-}" ]] || delete_keys+=("$key")
	done
	if [[ ${#delete_keys[@]} -gt 0 ]]; then
		command+=(-delete "$(join_csv "${delete_keys[@]}")")
	fi
	for key in "${original_keys[@]}"; do
		command+=("-${key}" "${original_values[$key]}")
	done

	if [[ ${#command[@]} -gt 5 ]] &&
		! "${command[@]}" >/dev/null; then
		warn "Rollback transaction failed for VM ${VMID}"
		return 1
	fi
	if ! verify_original_config; then
		warn "Rollback validation failed: ${VERIFY_REASON}"
		qm config "$VMID" |
			awk '/^hostpci[0-9]+:/ { print "  actual " $0 }' >&2
		return 1
	fi
	log "Rollback restored the original hostpci configuration"
}

cleanup() {
	local rc=$?

	if [[ "$rollback_needed" -eq 1 ]]; then
		if ! restore_original_config; then
			rc=2
		fi
	fi
	trap - EXIT
	exit "$rc"
}

verify_contiguous_config() {
	local index
	local key
	local value
	local actual_bdf
	local expected_bdf
	local -A actual=()

	VERIFY_REASON=""
	while IFS=$'\t' read -r key value; do
		[[ -n "$key" ]] || continue
		actual["$key"]="$value"
	done < <(
		qm config "$VMID" |
			awk -F': ' '/^hostpci[0-9]+:/ { printf "%s\t%s\n", $1, $2 }'
	)

	if [[ ${#actual[@]} -ne ${#selected_gpus[@]} ]]; then
		VERIFY_REASON="entry count is ${#actual[@]}, expected ${#selected_gpus[@]}"
		return 1
	fi
	for index in "${!selected_gpus[@]}"; do
		key="hostpci${index}"
		if [[ -z "${actual[$key]:-}" ]]; then
			VERIFY_REASON="missing ${key}"
			return 1
		fi
		actual_bdf="$(normalize_bdf "${actual[$key]}" || true)"
		expected_bdf="${selected_gpus[$index]}"
		if [[ "$actual_bdf" != "$expected_bdf" ]]; then
			VERIFY_REASON="${key} has ${actual_bdf:-invalid BDF}, expected ${expected_bdf}"
			return 1
		fi
		if [[ "${actual[$key]}" != *",pcie=1"* ]]; then
			VERIFY_REASON="${key} is missing pcie=1: ${actual[$key]}"
			return 1
		fi
	done
}

verify_original_config() {
	local key
	local value
	local -A actual=()

	VERIFY_REASON=""
	while IFS=$'\t' read -r key value; do
		[[ -n "$key" ]] || continue
		actual["$key"]="$value"
	done < <(
		qm config "$VMID" |
			awk -F': ' '/^hostpci[0-9]+:/ { printf "%s\t%s\n", $1, $2 }'
	)

	if [[ ${#actual[@]} -ne ${#original_keys[@]} ]]; then
		VERIFY_REASON="rollback entry count is ${#actual[@]}, expected ${#original_keys[@]}"
		return 1
	fi
	for key in "${original_keys[@]}"; do
		if [[ -z "${actual[$key]:-}" ]]; then
			VERIFY_REASON="rollback is missing ${key}"
			return 1
		fi
		if [[ "${actual[$key]}" != "${original_values[$key]}" ]]; then
			VERIFY_REASON="${key} rollback value differs: actual=${actual[$key]} expected=${original_values[$key]}"
			return 1
		fi
	done
}

apply_hostpci_transaction() {
	local key
	local bdf
	local value
	local index
	local -a delete_keys=()
	local -a command=(timeout "$QM_TIMEOUT" qm set "$VMID")
	local -A desired_key_set=()

	for index in "${!selected_gpus[@]}"; do
		desired_key_set["hostpci${index}"]=1
	done
	for key in "${current_keys[@]}"; do
		[[ -n "${desired_key_set[$key]:-}" ]] || delete_keys+=("$key")
	done
	if [[ ${#delete_keys[@]} -gt 0 ]]; then
		command+=(-delete "$(join_csv "${delete_keys[@]}")")
	fi
	for index in "${!selected_gpus[@]}"; do
		bdf="${selected_gpus[$index]}"
		value="$(value_for_gpu "$bdf")"
		command+=("-hostpci${index}" "$value")
	done

	[[ ${#command[@]} -gt 5 ]] || return 0
	"${command[@]}" >/dev/null
}

apply_config() {
	local status
	local key

	status="$(vm_status || true)"
	[[ "$status" != "running" ]] || die "VM ${VMID} is running; stop it before applying GPU changes"
	((${#selected_gpus[@]} <= MAX_HOSTPCI_DEVICES)) ||
		die "selected ${#selected_gpus[@]} GPUs, exceeding hostpci limit ${MAX_HOSTPCI_DEVICES}"

	load_current_hostpci
	if verify_contiguous_config; then
		log "VM ${VMID} already has the desired contiguous hostpci configuration"
		return 0
	fi
	original_keys=("${current_keys[@]}")
	for key in "${original_keys[@]}"; do
		original_values["$key"]="${current_values[$key]}"
	done

	mkdir -p "$BACKUP_DIR"
	backup_file="${BACKUP_DIR}/vm${VMID}-gpus-$(date '+%F-%H%M%S-%N').conf"
	cp -a "$CONF" "$backup_file"
	log "Saved VM config backup: ${backup_file}"

	rollback_needed=1
	apply_hostpci_transaction ||
		die "atomic hostpci configuration transaction failed"

	if ! verify_contiguous_config; then
		warn "Post-write validation failed: ${VERIFY_REASON}"
		qm config "$VMID" |
			awk '/^hostpci[0-9]+:/ { print "  actual " $0 }' >&2
		die "post-write validation failed; hostpci entries are not contiguous or complete"
	fi
	rollback_needed=0
	if [[ ${#selected_gpus[@]} -eq 0 ]]; then
		log "Applied an empty hostpci GPU set"
	else
		log "Applied ${#selected_gpus[@]} healthy GPUs as contiguous hostpci0..$(( ${#selected_gpus[@]} - 1 ))"
	fi
}

print_plan() {
	local bdf
	local index

	log "Visible ${GPU_VENDOR_ID} display GPUs: ${#visible_gpus[@]}"
	log "Selected healthy GPUs: ${#selected_gpus[@]}"
	for index in "${!selected_gpus[@]}"; do
		bdf="${selected_gpus[$index]}"
		printf 'hostpci%s: %s\n' "$index" "$(value_for_gpu "$bdf")"
		[[ -n "${gpu_warnings[$bdf]:-}" ]] &&
			warn "${bdf}: ${gpu_warnings[$bdf]}"
	done

	for bdf in "${skipped_gpus[@]}"; do
		warn "Skipping ${bdf}: ${skip_reasons[$bdf]}"
	done
}

parse_args() {
	if [[ $# -gt 0 && "$1" != --* ]]; then
		VMID="$1"
		shift
	fi

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--apply)
				MODE="apply"
				shift
				;;
			--dry-run)
				MODE="dry-run"
				shift
				;;
			--list)
				MODE="list"
				shift
				;;
			--only)
				[[ $# -ge 2 ]] || die "--only requires a comma-separated BDF list or 'none'"
				ONLY_SET=1
				ONLY_CSV="$2"
				shift 2
				;;
			--include-quarantined)
				INCLUDE_QUARANTINED=1
				shift
				;;
			--vfio-probe)
				VFIO_PROBE=1
				shift
				;;
			--no-vfio-probe)
				VFIO_PROBE=0
				shift
				;;
			--quarantine)
				[[ $# -ge 2 ]] || die "--quarantine requires a BDF"
				MODE="quarantine"
				QUARANTINE_BDF="$2"
				shift 2
				;;
			--unquarantine)
				[[ $# -ge 2 ]] || die "--unquarantine requires a BDF"
				MODE="unquarantine"
				UNQUARANTINE_BDF="$2"
				shift 2
				;;
			--reason)
				[[ $# -ge 2 ]] || die "--reason requires text"
				QUARANTINE_REASON="$2"
				shift 2
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				die "unknown argument: $1"
				;;
		esac
	done
}

main() {
	local bdf
	local status

	parse_args "$@"
	[[ "$VMID" =~ ^[1-9][0-9]*$ ]] || die "invalid VMID: ${VMID}"
	CONF="/etc/pve/qemu-server/${VMID}.conf"
	QUARANTINE_FILE="${STATE_DIR}/vm${VMID}.quarantine"
	CONFIG_LOCK_FILE="${STATE_DIR}/vm${VMID}.config.lock"

	[[ $EUID -eq 0 ]] || die "this script must run as root"
	require_cmd qm
	require_cmd lspci
	require_cmd setpci
	require_cmd timeout
	require_cmd flock
	require_cmd modprobe
	require_cmd perl
	[[ -f "$CONF" ]] || die "VM config not found: ${CONF}"

	case "$MODE" in
		quarantine)
			bdf="$(normalize_bdf "$QUARANTINE_BDF" || true)"
			[[ -n "$bdf" ]] || die "invalid quarantine BDF: ${QUARANTINE_BDF}"
			quarantine_gpu "$bdf" "$QUARANTINE_REASON"
			return 0
			;;
		unquarantine)
			bdf="$(normalize_bdf "$UNQUARANTINE_BDF" || true)"
			[[ -n "$bdf" ]] || die "invalid unquarantine BDF: ${UNQUARANTINE_BDF}"
			unquarantine_gpu "$bdf"
			return 0
			;;
	esac

	load_current_hostpci
	select_gpus || die "one or more explicitly requested GPUs failed health policy"

	case "$MODE" in
		list)
			if [[ ${#selected_gpus[@]} -gt 0 ]]; then
				printf '%s\n' "${selected_gpus[@]}"
			fi
			;;
		dry-run)
			print_plan
			log "Dry-run performs static checks only; lightweight VFIO realization is not executed"
			;;
		apply)
			status="$(vm_status || true)"
			[[ "$status" != "running" ]] ||
				die "VM ${VMID} is running; stop it before applying GPU changes"
			mkdir -p -m 700 "$STATE_DIR"
			exec 7>"$CONFIG_LOCK_FILE"
			flock -n 7 ||
				die "another GPU configuration job is active for VM ${VMID}"
			if [[ "$VFIO_PROBE" -eq 1 ]]; then
				run_vfio_diagnostics
			fi
			print_plan
			apply_config
			;;
		*)
			die "unsupported mode: ${MODE}"
			;;
	esac
}

trap cleanup EXIT
main "$@"
