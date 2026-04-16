#!/usr/bin/env bash

set -Eeuo pipefail

VMID="${1:-101}"
CONF="/etc/pve/qemu-server/${VMID}.conf"
BACKUP_DIR="/root/.vm-start-backups"
LOCK_FILE="/run/lock/start-vm${VMID}.lock"
LSPCI_TIMEOUT="${LSPCI_TIMEOUT:-2}"
QM_TIMEOUT="${QM_TIMEOUT:-20}"
PROBE_START_TIMEOUT="${PROBE_START_TIMEOUT:-45}"
FINAL_START_TIMEOUT="${FINAL_START_TIMEOUT:-90}"
STOP_WAIT_SECONDS="${STOP_WAIT_SECONDS:-20}"

declare -a hostpci_keys=()
declare -a candidate_keys=()
declare -a good_keys=()
declare -a bad_keys=()
declare -A hostpci_values=()
declare -A hostpci_slots=()
declare -A hostpci_desc=()

work_dir=""
active_conf=""
backup_file=""
restore_original_on_failure=1

log() {
	printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

warn() {
	printf '[%s] WARN: %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
	printf '[%s] ERROR: %s\n' "$(date '+%F %T')" "$*" >&2
	exit 1
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

vm_status() {
	local output

	output="$(timeout "$QM_TIMEOUT" qm status "$VMID" 2>/dev/null)" || return 1
	awk '{print $2}' <<<"$output"
}

ensure_vm_stopped() {
	local status
	local second

	status="$(vm_status || true)"
	case "$status" in
		stopped|'')
			return 0
			;;
		*)
			log "Stopping VM ${VMID}"
			timeout "$QM_TIMEOUT" qm stop "$VMID" --skiplock 1 >/dev/null 2>&1 || true
			;;
	esac

	for ((second = 0; second < STOP_WAIT_SECONDS; second++)); do
		status="$(vm_status || true)"
		[[ "$status" == "stopped" || -z "$status" ]] && return 0
		sleep 1
	done

	die "VM ${VMID} did not stop within ${STOP_WAIT_SECONDS}s"
}

normalize_slot() {
	local slot

	slot="${1%%,*}"
	slot="${slot,,}"

	if [[ "$slot" =~ ^[0-9a-f]{2}:[0-9a-f]{2}(\.[0-7])?$ ]]; then
		printf '0000:%s\n' "$slot"
		return 0
	fi

	if [[ "$slot" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}(\.[0-7])?$ ]]; then
		printf '%s\n' "$slot"
		return 0
	fi

	return 1
}

describe_slot() {
	local slot="$1"
	local output

	if [[ -z "$slot" ]]; then
		printf 'unavailable\n'
		return 0
	fi

	output="$(timeout "$LSPCI_TIMEOUT" lspci -Dnn -s "$slot" 2>/dev/null || true)"
	if [[ -n "$output" ]]; then
		printf '%s\n' "$output" | paste -sd '; ' -
	else
		printf 'unavailable\n'
	fi
}

is_gpu_candidate() {
	local slot="$1"
	local output
	local rc=0

	[[ -z "$slot" ]] && return 0

	output="$(timeout "$LSPCI_TIMEOUT" lspci -Dnn -s "$slot" 2>/dev/null)" || rc=$?

	if [[ $rc -eq 124 || $rc -eq 137 ]]; then
		warn "lspci timed out for ${slot}; treating it as a GPU candidate"
		return 0
	fi

	if [[ -z "$output" ]]; then
		return 0
	fi

	grep -Eq 'VGA compatible controller|3D controller|Display controller' <<<"$output"
}

delete_hostpci_key() {
	local key="$1"

	timeout "$QM_TIMEOUT" qm set "$VMID" -delete "$key" >/dev/null
}

set_hostpci_key() {
	local key="$1"
	local value="$2"

	timeout "$QM_TIMEOUT" qm set "$VMID" "-$key" "$value" >/dev/null
}

restore_original_config() {
	local key

	log "Restoring original hostpci configuration for VM ${VMID}"
	ensure_vm_stopped || true

	for key in "${candidate_keys[@]}"; do
		timeout "$QM_TIMEOUT" qm set "$VMID" -delete "$key" >/dev/null 2>&1 || true
	done

	for key in "${candidate_keys[@]}"; do
		timeout "$QM_TIMEOUT" qm set "$VMID" "-$key" "${hostpci_values[$key]}" >/dev/null 2>&1 || true
	done
}

cleanup() {
	local exit_code=$?

	if [[ $exit_code -ne 0 && $restore_original_on_failure -eq 1 ]]; then
		warn "Script failed before reaching a stable final config; restoring original hostpci entries"
		restore_original_config
	fi

	[[ -n "$work_dir" ]] && rm -rf "$work_dir"
}

qm_start_looks_successful() {
	local output_file="$1"
	local status

	if grep -Eq 'start failed:|TASK ERROR:|QEMU exited with code [1-9]' "$output_file"; then
		return 1
	fi

	status="$(vm_status || true)"
	[[ "$status" == "running" ]]
}

probe_current_config() {
	local label="$1"
	local output_file
	local rc=0

	output_file="$(mktemp "${work_dir}/start-${VMID}.XXXXXX.log")"

	timeout "$PROBE_START_TIMEOUT" qm start "$VMID" >"$output_file" 2>&1 || rc=$?

	if [[ $rc -eq 0 ]] && qm_start_looks_successful "$output_file"; then
		log "Probe succeeded: ${label}"
		ensure_vm_stopped
		rm -f "$output_file"
		return 0
	fi

	[[ $rc -eq 0 ]] && rc=1
	warn "Probe failed: ${label}"
	sed 's/^/  /' "$output_file" >&2 || true
	rm -f "$output_file"
	ensure_vm_stopped || true
	return "$rc"
}

start_final_config() {
	local output_file
	local rc=0

	output_file="$(mktemp "${work_dir}/final-${VMID}.XXXXXX.log")"

	timeout "$FINAL_START_TIMEOUT" qm start "$VMID" >"$output_file" 2>&1 || rc=$?

	if [[ $rc -eq 0 ]] && qm_start_looks_successful "$output_file"; then
		log "VM ${VMID} started successfully"
		rm -f "$output_file"
		return 0
	fi

	warn "Final start failed"
	sed 's/^/  /' "$output_file" >&2 || true
	rm -f "$output_file"
	return 1
}

print_summary() {
	local key

	log "Healthy passthrough GPUs retained: ${#good_keys[@]}"
	for key in "${good_keys[@]}"; do
		log "  keep ${key}: ${hostpci_values[$key]} (${hostpci_desc[$key]})"
	done

	log "Problematic passthrough GPUs removed: ${#bad_keys[@]}"
	for key in "${bad_keys[@]}"; do
		log "  drop ${key}: ${hostpci_values[$key]} (${hostpci_desc[$key]})"
	done
}

main() {
	local key
	local value
	local slot
	local status

	[[ $EUID -eq 0 ]] || die "this script must run as root"
	require_cmd qm
	require_cmd lspci
	require_cmd timeout
	require_cmd awk
	require_cmd grep
	require_cmd flock

	[[ -f "$CONF" ]] || die "VM config not found: $CONF"

	mkdir -p "$BACKUP_DIR"
	exec 9>"$LOCK_FILE"
	flock -n 9 || die "another start/probe job is already running for VM ${VMID}"

	work_dir="$(mktemp -d "/tmp/start-vm${VMID}.XXXXXX")"
	active_conf="${work_dir}/active.conf"
	backup_file="${BACKUP_DIR}/vm${VMID}-$(date '+%F-%H%M%S').conf"
	trap cleanup EXIT

	cp -a "$CONF" "$backup_file"
	awk '/^\[/ {exit} {print}' "$CONF" >"$active_conf"

	while IFS= read -r line; do
		[[ "$line" =~ ^(hostpci[0-9]+):[[:space:]]*(.+)$ ]] || continue
		key="${BASH_REMATCH[1]}"
		value="${BASH_REMATCH[2]}"
		slot="$(normalize_slot "$value" || true)"

		hostpci_keys+=("$key")
		hostpci_values["$key"]="$value"
		hostpci_slots["$key"]="$slot"
		hostpci_desc["$key"]="$(describe_slot "$slot")"
	done <"$active_conf"

	status="$(vm_status || true)"
	if [[ "$status" == "running" ]]; then
		log "VM ${VMID} is already running; nothing to do"
		restore_original_on_failure=0
		return 0
	fi

	if [[ ${#hostpci_keys[@]} -eq 0 ]]; then
		log "VM ${VMID} has no hostpci devices configured; starting directly"
		restore_original_on_failure=0
		start_final_config
		return 0
	fi

	for key in "${hostpci_keys[@]}"; do
		slot="${hostpci_slots[$key]}"
		if [[ -z "$slot" ]] || is_gpu_candidate "$slot"; then
			candidate_keys+=("$key")
		fi
	done

	if [[ ${#candidate_keys[@]} -eq 0 ]]; then
		candidate_keys=("${hostpci_keys[@]}")
	fi

	log "VM ${VMID} active config backup: ${backup_file}"
	log "GPU candidates to probe: ${#candidate_keys[@]}"
	for key in "${candidate_keys[@]}"; do
		log "  candidate ${key}: ${hostpci_values[$key]} (${hostpci_desc[$key]})"
	done

	ensure_vm_stopped

	for key in "${candidate_keys[@]}"; do
		log "Temporarily removing ${key}: ${hostpci_values[$key]}"
		delete_hostpci_key "$key"
	done

	if ! probe_current_config "baseline without passthrough GPUs"; then
		die "baseline start without passthrough GPUs failed; refusing to classify GPUs blindly"
	fi

	for key in "${candidate_keys[@]}"; do
		log "Probing ${key}: ${hostpci_values[$key]} (${hostpci_desc[$key]})"
		set_hostpci_key "$key" "${hostpci_values[$key]}"

		if probe_current_config "with ${key}=${hostpci_values[$key]}"; then
			good_keys+=("$key")
		else
			bad_keys+=("$key")
			log "Removing problematic device ${key}"
			delete_hostpci_key "$key"
		fi
	done

	print_summary

	restore_original_on_failure=0
	if ! start_final_config; then
		die "VM ${VMID} still failed to start after removing problematic passthrough GPUs; current config keeps only the validated subset"
	fi
}

main "$@"
