#!/usr/bin/env bash

set -Eeuo pipefail

VMID=101
DRY_RUN=0
INCLUDE_QUARANTINED=0
REVALIDATE_QUARANTINED=0

CONF=""
GPU_TOOL="${GPU_TOOL:-/root/qm_gpus.sh}"
STATE_FILE="${STATE_FILE:-/root/start_vm101.json}"
STATE_DIR="${STATE_DIR:-/root/.vm-gpu-state}"
RUN_ROOT="${RUN_ROOT:-/root/.vm-start-runs}"
CONF_ROOT="${CONF_ROOT:-/etc/pve/qemu-server}"
LOCK_ROOT="${LOCK_ROOT:-/run/lock}"
LOCK_FILE=""
RUN_DIR=""
REQUEST_ID=""
PVE_NODE=""

QM_TIMEOUT="${QM_TIMEOUT:-30}"
START_TIMEOUT_REQUESTED="${START_TIMEOUT:-auto}"
START_TIMEOUT=""
START_TIMEOUT_MODE=""
START_PROGRESS_INTERVAL="${START_PROGRESS_INTERVAL:-30}"
STORAGE_WAIT_TIMEOUT="${STORAGE_WAIT_TIMEOUT:-600}"
ENUMERATION_TIMEOUT="${ENUMERATION_TIMEOUT:-60}"
STOP_WAIT_SECONDS="${STOP_WAIT_SECONDS:-90}"
MAX_PRODUCTION_STARTS="${MAX_PRODUCTION_STARTS:-2}"

CURRENT_PHASE="initializing"
FINAL_MESSAGE=""
GPU_SOURCE="none"
last_start_log=""
last_gpu_log=""
last_enumerated_gpu_count=""
storage_state_lines=""
storage_all_ready=0
production_start_count=0
state_initialized=0
state_finalized=0
VM_MEMORY_MIB=0
last_start_duration_seconds=""
last_start_failure_kind=""
start_progress_pid=""

declare -a static_healthy_gpus=()
declare -a cached_gpus=()
declare -a configured_gpus=()
declare -a revalidation_candidates=()
declare -a recovered_gpus=()

export STATE_DIR

log() {
	printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

warn() {
	printf '[%s] WARN: %s\n' "$(date '+%F %T')" "$*" >&2
}

die() {
	FINAL_MESSAGE="$*"
	printf '[%s] ERROR: %s\n' "$(date '+%F %T')" "$*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage: start_vm101.sh [VMID] [--dry-run]
                      [--include-quarantined|--revalidate-quarantined]

Normal startup:
  1. Record the request and current host/VM/storage/GPU state in
     /root/start_vm101.json.
  2. If the last successful GPU list is still the complete healthy visible
     set, compact it to hostpci0..N and start VM101 once.
  3. If the cached set is stale or startup fails, diagnose PCI realization
     with a small 256 MiB QEMU/VFIO probe, update the GPU configuration, and
     make at most one further production-VM start.
  4. Promote a configuration to last_success only after QEMU enumerates every
     configured NVIDIA GPU.

The production-start deadline is sized automatically from configured VM
memory. Set START_TIMEOUT to a positive number of seconds to override it.

--dry-run performs read-only storage and PCI checks. It writes only diagnostic
logs and the JSON state record; it does not mount storage, bind PCI devices,
change VM configuration, or start/stop the VM.

--include-quarantined temporarily includes quarantined GPUs in this run but
never clears their quarantine records.

--revalidate-quarantined requires a stopped VM for a real run. It forces the
full static and combined VFIO probe path, includes quarantined GPUs, and clears
a recovered GPU's quarantine record only after the production VM starts and
QEMU enumerates every configured NVIDIA GPU. With --dry-run it is preview-only.
The script never stops a running VM automatically.
EOF
}

require_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

resolve_start_timeout() {
	local memory_gib
	local calculated

	VM_MEMORY_MIB="$(timeout "$QM_TIMEOUT" qm config "$VMID" |
		awk '$1 == "memory:" { print $2; exit }')"
	[[ "$VM_MEMORY_MIB" =~ ^[1-9][0-9]*$ ]] ||
		die "cannot determine configured memory for VM ${VMID}"

	if [[ "$START_TIMEOUT_REQUESTED" == "auto" ]]; then
		memory_gib=$(((VM_MEMORY_MIB + 1023) / 1024))
		calculated=$((300 + memory_gib * 2))
		((calculated < 900)) && calculated=900
		((calculated > 3600)) && calculated=3600
		START_TIMEOUT="$calculated"
		START_TIMEOUT_MODE="auto"
		log "Production-start timeout: ${START_TIMEOUT}s (auto-sized for ${memory_gib} GiB VM memory)"
	elif [[ "$START_TIMEOUT_REQUESTED" =~ ^[1-9][0-9]*$ ]]; then
		START_TIMEOUT="$START_TIMEOUT_REQUESTED"
		START_TIMEOUT_MODE="explicit"
		log "Production-start timeout: ${START_TIMEOUT}s (explicit override)"
	else
		die "START_TIMEOUT must be 'auto' or a positive integer"
	fi
}

parse_args() {
	if [[ $# -gt 0 && "$1" != --* ]]; then
		VMID="$1"
		shift
	fi

	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run)
				DRY_RUN=1
				shift
				;;
			--include-quarantined)
				INCLUDE_QUARANTINED=1
				shift
				;;
			--revalidate-quarantined)
				REVALIDATE_QUARANTINED=1
				INCLUDE_QUARANTINED=1
				shift
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

join_csv() {
	local IFS=','
	printf '%s' "$*"
}

arrays_equal() {
	local left_name="$1"
	local right_name="$2"
	local -n left="$left_name"
	local -n right="$right_name"
	local index

	[[ ${#left[@]} -eq ${#right[@]} ]] || return 1
	for index in "${!left[@]}"; do
		[[ "${left[$index]}" == "${right[$index]}" ]] || return 1
	done
}

array_contains() {
	local needle="$1"
	shift
	local item

	for item in "$@"; do
		[[ "$item" == "$needle" ]] && return 0
	done
	return 1
}

load_revalidation_candidates() {
	local quarantine_file="${STATE_DIR}/vm${VMID}.quarantine"
	local raw
	local bdf

	revalidation_candidates=()
	[[ "$REVALIDATE_QUARANTINED" -eq 1 ]] || return 0
	if [[ ! -f "$quarantine_file" ]]; then
		log "No quarantine records exist for VM ${VMID}; the full healthy inventory will still be probed"
		return 0
	fi

	while IFS=$'\t' read -r raw _; do
		[[ "$raw" =~ ^[[:space:]]*(#|$) ]] && continue
		bdf="$(normalize_bdf "$raw" || true)"
		[[ -n "$bdf" ]] || continue
		array_contains "$bdf" "${revalidation_candidates[@]}" ||
			revalidation_candidates+=("$bdf")
	done <"$quarantine_file"
	log "Quarantined GPUs scheduled for full revalidation (${#revalidation_candidates[@]}): ${revalidation_candidates[*]:-none}"
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

list_vm_volumes() {
	timeout "$QM_TIMEOUT" qm config "$VMID" | awk -F': ' '
		/^(efidisk|scsi|sata|virtio|ide|tpmstate)[0-9]+:/ {
			split($2, parts, ",")
			volume = parts[1]
			if (volume != "none" && volume ~ /^[^:]+:/) {
				print volume
			}
		}
	' | sort -u
}

collect_storage_state() {
	local volume
	local storage
	local path
	local mount_root
	local active
	local ready
	local storage_status_text
	local -a volumes=()
	local -a lines=()

	mapfile -t volumes < <(list_vm_volumes)
	storage_status_text="$(timeout "$QM_TIMEOUT" pvesm status 2>/dev/null || true)"
	storage_all_ready=1
	for volume in "${volumes[@]}"; do
		storage="${volume%%:*}"
		mount_root="/mnt/pve/${storage}"
		path="$(timeout "$QM_TIMEOUT" pvesm path "$volume" 2>/dev/null || true)"
		active=0
		ready=0
		if awk -v target="$storage" '
			NR > 1 && $1 == target && $3 == "active" { found = 1 }
			END { exit !found }
		' <<<"$storage_status_text"; then
			active=1
		fi
		if [[ "$active" -eq 1 && -n "$path" && -e "$path" ]]; then
			if [[ "$path" == "${mount_root}/"* || "$path" == "$mount_root" ]]; then
				mountpoint -q "$mount_root" && ready=1
			else
				ready=1
			fi
		fi
		[[ "$ready" -eq 1 ]] || storage_all_ready=0
		lines+=("$(printf '%s\t%s\t%s\t%s' "$volume" "$path" "$active" "$ready")")
	done

	storage_state_lines=""
	if [[ ${#lines[@]} -gt 0 ]]; then
		printf -v storage_state_lines '%s\n' "${lines[@]}"
		storage_state_lines="${storage_state_lines%$'\n'}"
	fi
}

activate_volume_mount() {
	local volume="$1"
	local storage="${volume%%:*}"
	local mount_root="/mnt/pve/${storage}"
	local mount_unit

	# pvesm status only proves that the storage backend is online. For block
	# backends such as LVM-thin, the individual LV can still be inactive and
	# its /dev path absent while the VM is stopped. Activate through PVE's
	# storage layer, the same mechanism used by qm start.
	log "Activating PVE storage volume ${volume}"
	timeout "$STORAGE_WAIT_TIMEOUT" perl -MPVE::Storage -e '
		my $volume = shift;
		my $cfg = PVE::Storage::config();
		PVE::Storage::activate_volumes($cfg, [$volume]);
	' "$volume" || die "failed to activate PVE storage volume ${volume}"

	# Keep support for externally managed directory mount units. In most PVE
	# storage plugins the call above already activates the backend, so this is
	# intentionally idempotent.
	mount_unit="$(systemd-escape --path --suffix=mount "$mount_root")"
	if systemctl cat "$mount_unit" >/dev/null 2>&1; then
		log "Ensuring storage mount ${mount_unit} is active for ${volume}"
		timeout "$STORAGE_WAIT_TIMEOUT" systemctl start "$mount_unit" ||
			die "failed to activate ${mount_unit}"
	fi
}

wait_for_vm_storage() {
	local deadline
	local next_report=0
	local now
	local volume
	local -a volumes=()
	local -a missing=()

	mapfile -t volumes < <(list_vm_volumes)
	log "Checking ${#volumes[@]} configured VM storage volumes"
	for volume in "${volumes[@]}"; do
		activate_volume_mount "$volume"
	done

	CURRENT_PHASE="storage_wait"
	collect_storage_state
	state_update "storage_check" "$CURRENT_PHASE" "in_progress" \
		"waiting for every configured volume to become active and readable" "" 0 0 0

	deadline=$((SECONDS + STORAGE_WAIT_TIMEOUT))
	while true; do
		collect_storage_state
		if [[ "$storage_all_ready" -eq 1 ]]; then
			log "All configured VM storage volumes are active and readable"
			state_update "storage_ready" "storage_ready" "success" \
				"all configured volumes are active, mounted where required, and readable" "" 0 0 0
			return 0
		fi

		missing=()
		while IFS=$'\t' read -r volume _ _ ready; do
			[[ "$ready" == "1" ]] || missing+=("$volume")
		done <<<"$storage_state_lines"

		now="$SECONDS"
		((now < deadline)) ||
			die "storage readiness timeout; unavailable: ${missing[*]}"
		if ((now >= next_report)); then
			warn "Waiting for storage: ${missing[*]}"
			state_update "storage_wait" "$CURRENT_PHASE" "in_progress" \
				"waiting for unavailable volumes: ${missing[*]}" "" 0 0 0
			next_report=$((now + 15))
		fi
		sleep 2
	done
}

configured_gpu_list() {
	local line
	local value
	local bdf

	while IFS= read -r line; do
		[[ "$line" =~ ^hostpci[0-9]+:[[:space:]]*(.+)$ ]] || continue
		value="${BASH_REMATCH[1]}"
		bdf="$(normalize_bdf "$value" || true)"
		[[ -n "$bdf" ]] && printf '%s\n' "$bdf"
	done < <(
		timeout "$QM_TIMEOUT" qm config "$VMID" |
			awk -F: '/^hostpci[0-9]+:/ { key=$1; sub(/^hostpci/, "", key); print key "\t" $0 }' |
			sort -n -k1,1 |
			cut -f2-
	)
}

qemu_monitor_gpu_count() {
	local output

	output="$(timeout "$QM_TIMEOUT" pvesh create \
		"/nodes/${PVE_NODE}/qemu/${VMID}/monitor" \
		--command "info pci" 2>/dev/null || true)"
	grep -Eic '(VGA|3D|Display) controller: PCI device 10de:' <<<"$output" || true
}

report_start_progress() {
	local started_epoch="$1"
	local elapsed
	local status
	local pid=""
	local rss_kib=""
	local rss_gib=""
	local target_gib

	elapsed=$(($(date +%s) - started_epoch))
	status="$(vm_status || true)"
	[[ -n "$status" ]] || status="unknown"
	if [[ -r "/run/qemu-server/${VMID}.pid" ]]; then
		pid="$(<"/run/qemu-server/${VMID}.pid")"
	fi
	if [[ "$pid" =~ ^[1-9][0-9]*$ && -r "/proc/${pid}/status" ]]; then
		rss_kib="$(awk '$1 == "VmRSS:" { print $2; exit }' "/proc/${pid}/status")"
	fi
	target_gib="$(awk -v mib="$VM_MEMORY_MIB" 'BEGIN { printf "%.1f", mib / 1024 }')"
	if [[ "$rss_kib" =~ ^[0-9]+$ ]]; then
		rss_gib="$(awk -v kib="$rss_kib" 'BEGIN { printf "%.1f", kib / 1048576 }')"
		log "VM ${VMID} is still initializing: elapsed=${elapsed}s/${START_TIMEOUT}s, status=${status}, QEMU_RSS=${rss_gib}/${target_gib} GiB"
	else
		log "VM ${VMID} is still initializing: elapsed=${elapsed}s/${START_TIMEOUT}s, status=${status}, QEMU process/RSS not available yet"
	fi
}

start_progress_monitor() {
	local started_epoch="$1"

	while sleep "$START_PROGRESS_INTERVAL"; do
		report_start_progress "$started_epoch"
	done
}

stop_progress_monitor() {
	if [[ "$start_progress_pid" =~ ^[1-9][0-9]*$ ]]; then
		kill "$start_progress_pid" >/dev/null 2>&1 || true
		wait "$start_progress_pid" 2>/dev/null || true
	fi
	start_progress_pid=""
}

state_update() {
	local action="$1"
	local phase="$2"
	local result="$3"
	local message="$4"
	local log_path="$5"
	local exit_code="$6"
	local is_attempt="$7"
	local promote_success="$8"
	local status
	local config_text
	local config_sha=""
	local boot_id=""
	local kernel=""
	local pid=""
	local enum_count="$last_enumerated_gpu_count"

	status="$(vm_status || true)"
	[[ -n "$status" ]] || status="unknown"
	config_text="$(timeout "$QM_TIMEOUT" qm config "$VMID" 2>/dev/null || true)"
	[[ -f "$CONF" ]] && config_sha="$(sha256sum "$CONF" | awk '{print $1}')"
	[[ -r /proc/sys/kernel/random/boot_id ]] &&
		boot_id="$(</proc/sys/kernel/random/boot_id)"
	kernel="$(uname -r)"
	if [[ "$status" == "running" ]]; then
		[[ -r "/run/qemu-server/${VMID}.pid" ]] &&
			pid="$(<"/run/qemu-server/${VMID}.pid")"
	else
		enum_count=""
	fi

	STATE_PATH="$STATE_FILE" \
	STATE_NOW="$(date -Is)" \
	STATE_ACTION="$action" \
	STATE_PHASE_VALUE="$phase" \
	STATE_RESULT="$result" \
	STATE_MESSAGE="$message" \
	STATE_LOG_PATH="$log_path" \
	STATE_EXIT_CODE="$exit_code" \
	STATE_IS_ATTEMPT="$is_attempt" \
	STATE_PROMOTE_SUCCESS="$promote_success" \
	STATE_VMID="$VMID" \
	STATE_REQUEST_ID="$REQUEST_ID" \
	STATE_RUN_DIR="$RUN_DIR" \
	STATE_DRY_RUN="$DRY_RUN" \
	STATE_INCLUDE_QUARANTINED="$INCLUDE_QUARANTINED" \
	STATE_REVALIDATE_QUARANTINED="$REVALIDATE_QUARANTINED" \
	STATE_REVALIDATION_CANDIDATES="$(join_csv "${revalidation_candidates[@]}")" \
	STATE_RECOVERED_GPUS="$(join_csv "${recovered_gpus[@]}")" \
	STATE_QM_TIMEOUT="$QM_TIMEOUT" \
	STATE_START_TIMEOUT="$START_TIMEOUT" \
	STATE_START_TIMEOUT_MODE="$START_TIMEOUT_MODE" \
	STATE_START_PROGRESS_INTERVAL="$START_PROGRESS_INTERVAL" \
	STATE_VM_MEMORY_MIB="$VM_MEMORY_MIB" \
	STATE_START_DURATION="$last_start_duration_seconds" \
	STATE_START_FAILURE_KIND="$last_start_failure_kind" \
	STATE_STORAGE_TIMEOUT="$STORAGE_WAIT_TIMEOUT" \
	STATE_ENUM_TIMEOUT="$ENUMERATION_TIMEOUT" \
	STATE_STOP_TIMEOUT="$STOP_WAIT_SECONDS" \
	STATE_MAX_STARTS="$MAX_PRODUCTION_STARTS" \
	STATE_GPU_SOURCE="$GPU_SOURCE" \
	STATE_QUARANTINE_FILE="${STATE_DIR}/vm${VMID}.quarantine" \
	STATE_STORAGE_LINES="$storage_state_lines" \
	STATE_STORAGE_READY="$storage_all_ready" \
	STATE_VM_STATUS="$status" \
	STATE_VM_PID="$pid" \
	STATE_ENUM_GPU_COUNT="$enum_count" \
	STATE_CONFIG_TEXT="$config_text" \
	STATE_CONFIG_SHA="$config_sha" \
	STATE_BOOT_ID="$boot_id" \
	STATE_KERNEL="$kernel" \
	perl -MJSON::PP -MFile::Basename=dirname -e '
		use strict;
		use warnings;

		sub boolean {
			return ($_[0] // q{}) ne q{} && ($_[0] // q{}) ne q{0}
				? JSON::PP::true : JSON::PP::false;
		}

		sub normalize_bdf {
			my ($value) = @_;
			$value = lc($value // q{});
			$value =~ s/,.*$//;
			if ($value =~ /^([0-9a-f]{2}):([0-9a-f]{2})(?:\.[0-7])?$/) {
				return "0000:$1:$2";
			}
			if ($value =~ /^([0-9a-f]{4}):([0-9a-f]{2}):([0-9a-f]{2})(?:\.[0-7])?$/) {
				return "$1:$2:$3";
			}
			return undef;
		}

		sub csv_array {
			my ($value) = @_;
			return [] if !defined($value) || $value eq q{};
			return [grep { $_ ne q{} } split /,/, $value];
		}

		my $path = $ENV{STATE_PATH};
		my $json = JSON::PP->new->canonical(1)->pretty(1);
		my $state = {};
		if (-e $path) {
			if (open my $in, q{<}, $path) {
				local $/;
				my $raw = <$in>;
				close $in;
				my $decoded = eval { $json->decode($raw) };
				if (!$@ && ref($decoded) eq q{HASH}) {
					$state = $decoded;
				} else {
					my $corrupt = $path . q{.corrupt.} . time() . q{.} . $$;
					rename $path, $corrupt
						or die "cannot preserve corrupt state as $corrupt: $!";
				}
			} else {
				die "cannot read $path: $!";
			}
		}

		my %raw_config;
		for my $line (split /\n/, ($ENV{STATE_CONFIG_TEXT} // q{})) {
			next unless $line =~ /^([^:\s]+):\s*(.*)$/;
			$raw_config{$1} = $2;
		}

		my %safe_config;
		my %allowed = map { $_ => 1 } qw(
			name memory balloon cores sockets cpu numa machine bios ostype
			scsihw boot onboot agent hugepages
		);
		for my $key (sort keys %allowed) {
			$safe_config{$key} = $raw_config{$key} if exists $raw_config{$key};
		}

		my @hostpci_keys = sort {
			($a =~ /(\d+)$/)[0] <=> ($b =~ /(\d+)$/)[0]
		} grep { /^hostpci\d+$/ } keys %raw_config;
		my %hostpci;
		my @configured_gpus;
		for my $key (@hostpci_keys) {
			my $bdf = normalize_bdf($raw_config{$key});
			$hostpci{$key} = {
				value => $raw_config{$key},
				(defined $bdf ? (bdf => $bdf) : ()),
			};
			push @configured_gpus, $bdf if defined $bdf;
		}

		my @volumes;
		for my $line (split /\n/, ($ENV{STATE_STORAGE_LINES} // q{})) {
			next if $line eq q{};
			my ($volid, $volume_path, $active, $ready) = split /\t/, $line, 4;
			push @volumes, {
				volid => ($volid // q{}),
				path => ($volume_path // q{}),
				active => boolean($active),
				ready => boolean($ready),
			};
		}

		my @quarantine;
		my $quarantine_path = $ENV{STATE_QUARANTINE_FILE} // q{};
		if ($quarantine_path ne q{} && open my $qf, q{<}, $quarantine_path) {
			while (my $line = <$qf>) {
				chomp $line;
				next if $line =~ /^\s*(?:#|$)/;
				my ($bdf, $timestamp, $reason) = split /\t/, $line, 3;
				push @quarantine, {
					bdf => ($bdf // q{}),
					timestamp => ($timestamp // q{}),
					reason => ($reason // q{}),
				};
			}
			close $qf;
		}

		my $parameters = {
			dry_run => boolean($ENV{STATE_DRY_RUN}),
			include_quarantined => boolean($ENV{STATE_INCLUDE_QUARANTINED}),
			revalidate_quarantined => boolean($ENV{STATE_REVALIDATE_QUARANTINED}),
			qm_timeout_seconds => 0 + ($ENV{STATE_QM_TIMEOUT} // 0),
			start_timeout_seconds => 0 + ($ENV{STATE_START_TIMEOUT} // 0),
			start_timeout_mode => ($ENV{STATE_START_TIMEOUT_MODE} // q{}),
			start_progress_interval_seconds =>
				0 + ($ENV{STATE_START_PROGRESS_INTERVAL} // 0),
			vm_memory_mib => 0 + ($ENV{STATE_VM_MEMORY_MIB} // 0),
			storage_wait_timeout_seconds => 0 + ($ENV{STATE_STORAGE_TIMEOUT} // 0),
			enumeration_timeout_seconds => 0 + ($ENV{STATE_ENUM_TIMEOUT} // 0),
			stop_wait_seconds => 0 + ($ENV{STATE_STOP_TIMEOUT} // 0),
			max_production_starts => 0 + ($ENV{STATE_MAX_STARTS} // 0),
		};

		$state->{schema_version} = 1;
		$state->{vmid} = 0 + $ENV{STATE_VMID};
		$state->{updated_at} = $ENV{STATE_NOW};
		$state->{phase} = $ENV{STATE_PHASE_VALUE};
		$state->{result} = $ENV{STATE_RESULT};
		$state->{message} = $ENV{STATE_MESSAGE};
		$state->{host} = {
			boot_id => ($ENV{STATE_BOOT_ID} // q{}),
			kernel => ($ENV{STATE_KERNEL} // q{}),
		};
		$state->{parameters} = $parameters;
		$state->{storage} = {
			status => boolean($ENV{STATE_STORAGE_READY}) ? q{ready} : q{not_ready},
			volumes => \@volumes,
		};
		$state->{gpu} = {
			source => ($ENV{STATE_GPU_SOURCE} // q{none}),
			quarantine => \@quarantine,
			revalidation_candidates => csv_array($ENV{STATE_REVALIDATION_CANDIDATES}),
			recovered_from_quarantine => csv_array($ENV{STATE_RECOVERED_GPUS}),
		};
		$state->{vm} = {
			status => ($ENV{STATE_VM_STATUS} // q{unknown}),
			config_sha256 => ($ENV{STATE_CONFIG_SHA} // q{}),
			config => \%safe_config,
			hostpci => \%hostpci,
			configured_gpus => \@configured_gpus,
			configured_gpu_count => scalar(@configured_gpus),
		};
		if (($ENV{STATE_VM_PID} // q{}) =~ /^\d+$/) {
			$state->{vm}{pid} = 0 + $ENV{STATE_VM_PID};
		}
		if (($ENV{STATE_ENUM_GPU_COUNT} // q{}) =~ /^\d+$/) {
			my $count = 0 + $ENV{STATE_ENUM_GPU_COUNT};
			$state->{vm}{enumerated_gpu_count} = $count;
			$state->{vm}{enumeration_complete} =
				$count == scalar(@configured_gpus)
				? JSON::PP::true : JSON::PP::false;
		}

		if (($ENV{STATE_ACTION} // q{}) eq q{init}) {
			$state->{request} = {
				id => ($ENV{STATE_REQUEST_ID} // q{}),
				started_at => $ENV{STATE_NOW},
				log_dir => ($ENV{STATE_RUN_DIR} // q{}),
				parameters => $parameters,
			};
		}

		if (boolean($ENV{STATE_IS_ATTEMPT})) {
			$state->{last_attempt} = {
				timestamp => $ENV{STATE_NOW},
				result => $ENV{STATE_RESULT},
				exit_code => 0 + ($ENV{STATE_EXIT_CODE} // 0),
				log => ($ENV{STATE_LOG_PATH} // q{}),
				message => ($ENV{STATE_MESSAGE} // q{}),
				vm_status => ($ENV{STATE_VM_STATUS} // q{unknown}),
				configured_gpus => [@configured_gpus],
				source => ($ENV{STATE_GPU_SOURCE} // q{none}),
			};
			if (($ENV{STATE_START_DURATION} // q{}) =~ /^\d+$/) {
				$state->{last_attempt}{duration_seconds} =
					0 + $ENV{STATE_START_DURATION};
			}
			if (($ENV{STATE_START_FAILURE_KIND} // q{}) ne q{}) {
				$state->{last_attempt}{failure_kind} =
					$ENV{STATE_START_FAILURE_KIND};
			}
		}

		if (boolean($ENV{STATE_PROMOTE_SUCCESS})) {
			$state->{last_success} = {
				timestamp => $ENV{STATE_NOW},
				config_sha256 => ($ENV{STATE_CONFIG_SHA} // q{}),
				configured_gpus => [@configured_gpus],
				hostpci => {%hostpci},
				enumerated_gpu_count =>
					0 + ($ENV{STATE_ENUM_GPU_COUNT} // scalar(@configured_gpus)),
				parameters => $parameters,
				source => ($ENV{STATE_GPU_SOURCE} // q{none}),
				host_boot_id => ($ENV{STATE_BOOT_ID} // q{}),
			};
			if (($ENV{STATE_START_DURATION} // q{}) =~ /^\d+$/) {
				$state->{last_success}{duration_seconds} =
					0 + $ENV{STATE_START_DURATION};
			}
		}

		if (($ENV{STATE_RESULT} // q{}) eq q{failed}) {
			$state->{last_failure} = {
				timestamp => $ENV{STATE_NOW},
				phase => ($ENV{STATE_PHASE_VALUE} // q{}),
				message => ($ENV{STATE_MESSAGE} // q{}),
				log => ($ENV{STATE_LOG_PATH} // q{}),
				exit_code => 0 + ($ENV{STATE_EXIT_CODE} // 0),
			};
		}

		my $history = ref($state->{history}) eq q{ARRAY} ? $state->{history} : [];
		push @$history, {
			timestamp => $ENV{STATE_NOW},
			action => ($ENV{STATE_ACTION} // q{}),
			phase => ($ENV{STATE_PHASE_VALUE} // q{}),
			result => ($ENV{STATE_RESULT} // q{}),
			message => ($ENV{STATE_MESSAGE} // q{}),
			exit_code => 0 + ($ENV{STATE_EXIT_CODE} // 0),
			vm_status => ($ENV{STATE_VM_STATUS} // q{unknown}),
			gpu_source => ($ENV{STATE_GPU_SOURCE} // q{none}),
		};
		if (($ENV{STATE_START_DURATION} // q{}) =~ /^\d+$/) {
			$history->[-1]{duration_seconds} =
				0 + $ENV{STATE_START_DURATION};
		}
		if (($ENV{STATE_START_FAILURE_KIND} // q{}) ne q{}) {
			$history->[-1]{failure_kind} =
				$ENV{STATE_START_FAILURE_KIND};
		}
		splice @$history, 0, @$history - 30 if @$history > 30;
		$state->{history} = $history;

		my $dir = dirname($path);
		-d $dir or mkdir $dir, 0700 or die "cannot create $dir: $!";
		my $tmp = $path . q{.tmp.} . $$;
		open my $out, q{>}, $tmp or die "cannot create $tmp: $!";
		chmod 0600, $tmp or die "cannot chmod $tmp: $!";
		print {$out} $json->encode($state)
			or die "cannot write $tmp: $!";
		close $out or die "cannot close $tmp: $!";
		rename $tmp, $path or die "cannot replace $path: $!";
		chmod 0600, $path or die "cannot chmod $path: $!";
	'
}

state_has_last_success() {
	[[ -f "$STATE_FILE" ]] || return 1
	perl -MJSON::PP -0777 -e '
		my $s = eval { JSON::PP->new->decode(<>) };
		exit 1 unless ref($s) eq q{HASH};
		exit 1 unless ref($s->{last_success}) eq q{HASH};
		exit 1 unless ref($s->{last_success}{configured_gpus}) eq q{ARRAY};
		exit 0;
	' "$STATE_FILE"
}

read_last_success_gpus() {
	perl -MJSON::PP -0777 -e '
		my $s = JSON::PP->new->decode(<>);
		print "$_\n" for @{$s->{last_success}{configured_gpus}};
	' "$STATE_FILE"
}

load_static_healthy_gpus() {
	local list_file="${RUN_DIR}/gpu-static.list"
	local error_file="${RUN_DIR}/gpu-static.log"
	local -a args=("$VMID" "--list")

	[[ "$INCLUDE_QUARANTINED" -eq 1 ]] && args+=("--include-quarantined")
	if ! "$GPU_TOOL" "${args[@]}" >"$list_file" 2>"$error_file"; then
		sed -n '1,160p' "$error_file" >&2 || true
		return 1
	fi
	sed -n '1,160p' "$error_file" >&2 || true
	mapfile -t static_healthy_gpus <"$list_file"
	log "Statically healthy visible GPUs (${#static_healthy_gpus[@]}): ${static_healthy_gpus[*]:-none}"
}

run_gpu_tool_logged() {
	local label="$1"
	shift
	local log_file="${RUN_DIR}/${label}.log"
	local rc=0

	last_gpu_log="$log_file"
	if "$GPU_TOOL" "$@" >"$log_file" 2>&1; then
		rc=0
	else
		rc=$?
	fi
	sed -n '1,220p' "$log_file" || true
	return "$rc"
}

apply_cached_gpu_config() {
	local only="none"
	local -a args=("$VMID" "--apply" "--no-vfio-probe")

	if [[ ${#cached_gpus[@]} -gt 0 ]]; then
		only="$(join_csv "${cached_gpus[@]}")"
	fi
	args+=("--only" "$only")
	[[ "$INCLUDE_QUARANTINED" -eq 1 ]] && args+=("--include-quarantined")

	CURRENT_PHASE="gpu_cached_apply"
	GPU_SOURCE="last_success"
	log "Reusing the complete last-success GPU set: ${cached_gpus[*]:-none}"
	run_gpu_tool_logged "gpu-cached-apply" "${args[@]}" ||
		return 1
	mapfile -t configured_gpus < <(configured_gpu_list)
	state_update "gpu_config" "$CURRENT_PHASE" "success" \
		"applied last-success GPUs as contiguous hostpci0..N" "$last_gpu_log" 0 0 0
}

run_gpu_diagnosis() {
	local -a args=("$VMID" "--apply" "--vfio-probe")

	[[ "$INCLUDE_QUARANTINED" -eq 1 ]] && args+=("--include-quarantined")
	CURRENT_PHASE="gpu_diagnosis"
	GPU_SOURCE="diagnosed"
	log "Running lightweight PCI/VFIO diagnosis without booting VM ${VMID}"
	state_update "gpu_diagnosis" "$CURRENT_PHASE" "in_progress" \
		"static PCI checks and a 256 MiB QEMU/VFIO realization probe are running" "" 0 0 0
	if ! run_gpu_tool_logged "gpu-diagnosis-$(date '+%H%M%S')" "${args[@]}"; then
		state_update "gpu_diagnosis" "$CURRENT_PHASE" "failed" \
			"lightweight GPU diagnosis or configuration failed" "$last_gpu_log" 1 0 0
		return 1
	fi
	mapfile -t configured_gpus < <(configured_gpu_list)
	log "Diagnosed GPU configuration (${#configured_gpus[@]}): ${configured_gpus[*]:-none}"
	state_update "gpu_diagnosis" "$CURRENT_PHASE" "success" \
		"lightweight diagnosis completed and hostpci entries were compacted" "$last_gpu_log" 0 0 0
}

quarantine_gpu() {
	local bdf="$1"
	local reason="$2"

	run_gpu_tool_logged "gpu-quarantine-${bdf//:/-}" \
		"$VMID" --quarantine "$bdf" --reason "$reason"
}

promote_revalidated_gpus() {
	local bdf
	local log_file="${RUN_DIR}/gpu-revalidation-promote.log"

	recovered_gpus=()
	[[ "$REVALIDATE_QUARANTINED" -eq 1 ]] || return 0
	mapfile -t configured_gpus < <(configured_gpu_list)
	if [[ ! "$last_enumerated_gpu_count" =~ ^[0-9]+$ ]] ||
		[[ "$last_enumerated_gpu_count" -ne ${#configured_gpus[@]} ]]; then
		warn "Refusing to clear quarantine before complete QEMU GPU enumeration"
		return 1
	fi

	: >"$log_file"
	chmod 600 "$log_file"
	for bdf in "${revalidation_candidates[@]}"; do
		if ! array_contains "$bdf" "${configured_gpus[@]}"; then
			warn "Keeping ${bdf} quarantined: it was not in the verified production GPU set"
			printf 'kept %s quarantined: not in verified production set\n' "$bdf" >>"$log_file"
			continue
		fi

		log "Promoting recovered GPU ${bdf} after full production enumeration"
		if "$GPU_TOOL" "$VMID" --unquarantine "$bdf" >>"$log_file" 2>&1; then
			recovered_gpus+=("$bdf")
		else
			warn "Failed to persist quarantine removal for recovered GPU ${bdf}"
			sed -n '1,160p' "$log_file" >&2 || true
			return 1
		fi
	done
	last_gpu_log="$log_file"
	if [[ ${#recovered_gpus[@]} -gt 0 ]]; then
		log "Recovered GPUs removed from quarantine (${#recovered_gpus[@]}): ${recovered_gpus[*]}"
	else
		log "No quarantined GPU completed the full production revalidation path"
	fi
}

verify_gpu_enumeration() {
	local expected="$1"
	local label="$2"
	local deadline=$((SECONDS + ENUMERATION_TIMEOUT))
	local count=0
	local output
	local monitor_log="${RUN_DIR}/monitor-${label}.log"

	while [[ "$SECONDS" -lt "$deadline" ]]; do
		output="$(timeout "$QM_TIMEOUT" pvesh create \
			"/nodes/${PVE_NODE}/qemu/${VMID}/monitor" \
			--command "info pci" 2>/dev/null || true)"
		printf '%s\n' "$output" >"$monitor_log"
		count="$(grep -Eic '(VGA|3D|Display) controller: PCI device 10de:' <<<"$output" || true)"
		last_enumerated_gpu_count="$count"
		if [[ "$count" -eq "$expected" ]]; then
			log "QEMU enumerated all ${expected} configured NVIDIA GPUs"
			return 0
		fi
		sleep 2
	done

	warn "GPU enumeration incomplete: configured=${expected}, QEMU-visible=${count}"
	return 1
}

stop_failed_start() {
	local status
	local deadline=$((SECONDS + STOP_WAIT_SECONDS))

	status="$(vm_status || true)"
	[[ "$status" == "running" ]] || return 0
	log "Stopping the failed VM ${VMID} start attempt"
	timeout "$STOP_WAIT_SECONDS" qm stop "$VMID" --skiplock 1 >/dev/null 2>&1 || true
	while [[ "$SECONDS" -lt "$deadline" ]]; do
		status="$(vm_status || true)"
		if [[ "$status" != "running" ]]; then
			last_enumerated_gpu_count=""
			state_update "vm_stop" "stopped_after_failure" "success" \
				"failed production start was stopped before further diagnosis" "$last_start_log" 0 0 0
			return 0
		fi
		sleep 1
	done
	die "VM ${VMID} did not stop within ${STOP_WAIT_SECONDS} seconds"
}

production_start() {
	local label="$1"
	local expected_gpus="$2"
	local output_file
	local rc=0
	local status
	local started_epoch
	local success_message

	production_start_count=$((production_start_count + 1))
	((production_start_count <= MAX_PRODUCTION_STARTS)) ||
		die "refusing production start ${production_start_count}; limit is ${MAX_PRODUCTION_STARTS}"

	CURRENT_PHASE="production_start"
	last_enumerated_gpu_count=""
	last_start_duration_seconds=""
	last_start_failure_kind=""
	output_file="${RUN_DIR}/production-$(printf '%02d' "$production_start_count")-${label}.log"
	last_start_log="$output_file"
	log "Production start ${production_start_count}/${MAX_PRODUCTION_STARTS}: ${label} (${expected_gpus} GPUs)"
	state_update "production_start" "$CURRENT_PHASE" "in_progress" \
		"starting VM ${VMID} with ${expected_gpus} configured GPUs" "$output_file" 0 0 0

	started_epoch="$(date +%s)"
	start_progress_monitor "$started_epoch" &
	start_progress_pid=$!
	# Do not let the long-lived QEMU process inherit the workflow lock. The
	# parent script keeps fd 9 until orchestration is fully finalized.
	timeout --foreground --kill-after=10 "$START_TIMEOUT" \
		qm start "$VMID" 9>&- >"$output_file" 2>&1 || rc=$?
	stop_progress_monitor
	last_start_duration_seconds=$(($(date +%s) - started_epoch))
	status="$(vm_status || true)"
	if [[ "$status" == "running" ]] &&
		verify_gpu_enumeration "$expected_gpus" "${production_start_count}-${label}"; then
		if [[ "$rc" -ne 0 ]]; then
			warn "qm start returned ${rc}, but the VM is running with complete GPU enumeration; checking stability"
			sleep 10
			status="$(vm_status || true)"
			last_enumerated_gpu_count="$(qemu_monitor_gpu_count)"
			if [[ "$status" != "running" ||
				"$last_enumerated_gpu_count" -ne "$expected_gpus" ]]; then
				last_start_failure_kind="command_failure"
			else
				warn "Preserving the healthy running VM after a non-zero qm start result"
			fi
		fi
	fi
	if [[ "$status" == "running" &&
		"$last_enumerated_gpu_count" -eq "$expected_gpus" &&
		"$last_start_failure_kind" != "command_failure" ]]; then
		success_message="VM started in ${last_start_duration_seconds}s and QEMU enumerated every configured GPU"
		state_update "production_start" "running" "success" \
			"$success_message" "$output_file" "$rc" 1 0
		return 0
	fi

	if [[ "$rc" -eq 124 ]]; then
		last_start_failure_kind="orchestration_timeout"
	else
		last_start_failure_kind="start_or_enumeration_failure"
	fi
	warn "Production start failed: command_rc=${rc}, VM_status=${status:-unknown}"
	sed -n '1,160p' "$output_file" | sed 's/^/  /' >&2 || true
	state_update "production_start" "$CURRENT_PHASE" "failed" \
		"production start or complete GPU enumeration failed after ${last_start_duration_seconds}s" \
		"$output_file" "$rc" 1 0
	stop_failed_start
	return 1
}

extract_unique_fault_gpu() {
	local log_file="$1"
	local line
	local token
	local bdf
	local configured
	local -a candidates=()
	local -a strong_lines=()

	[[ -f "$log_file" ]] || return 1
	mapfile -t strong_lines < <(
		grep -Ei \
			'(vfio|iommu|bar|reset|pcie?|device).*(fail|error|cannot|unable|not available|timeout|invalid)|(fail|error|cannot|unable|not available|timeout|invalid).*(vfio|iommu|bar|reset|pcie?|device)' \
			"$log_file" || true
	)
	for line in "${strong_lines[@]}"; do
		while IFS= read -r token; do
			bdf="$(normalize_bdf "$token" || true)"
			[[ -n "$bdf" ]] || continue
			for configured in "${configured_gpus[@]}"; do
				if [[ "$bdf" == "$configured" ]]; then
					if ! printf '%s\n' "${candidates[@]:-}" | grep -Fxq "$bdf"; then
						candidates+=("$bdf")
					fi
				fi
			done
		done < <(grep -Eio '([0-9a-f]{4}:)?[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]' <<<"$line" || true)
	done

	[[ ${#candidates[@]} -eq 1 ]] || return 1
	printf '%s\n' "${candidates[0]}"
}

prepare_after_identified_failure() {
	local bdf="$1"
	local reason="$2"

	warn "Production log identifies one configured GPU as faulty: ${bdf}"
	quarantine_gpu "$bdf" "$reason" ||
		return 1
	run_gpu_diagnosis
}

finalize_success() {
	CURRENT_PHASE="running"
	if [[ "$REVALIDATE_QUARANTINED" -eq 1 ]]; then
		GPU_SOURCE="revalidated"
		promote_revalidated_gpus ||
			die "VM ${VMID} is healthy and running, but recovered GPU quarantine state could not be persisted"
	fi
	state_update "complete" "$CURRENT_PHASE" "success" \
		"VM ${VMID} is running with the verified GPU configuration" "$last_start_log" 0 0 1
	state_finalized=1
	log "VM ${VMID} startup succeeded; last_success was updated in ${STATE_FILE}"
}

handle_final_start_failure() {
	local bad_gpu=""

	bad_gpu="$(extract_unique_fault_gpu "$last_start_log" || true)"
	if [[ -n "$bad_gpu" ]]; then
		prepare_after_identified_failure "$bad_gpu" \
			"production QEMU log identified this device after lightweight validation" || true
		warn "Configuration was updated for the next controlled start; no third production start will be attempted"
	fi
	die "VM ${VMID} did not reach a fully enumerated running state; see ${last_start_log}"
}

run_dry_run() {
	local -a args=("$VMID" "--dry-run")
	local status

	CURRENT_PHASE="dry_run"
	GPU_SOURCE="static_check"
	collect_storage_state
	[[ "$INCLUDE_QUARANTINED" -eq 1 ]] && args+=("--include-quarantined")
	if ! run_gpu_tool_logged "gpu-dry-run" "${args[@]}"; then
		die "GPU dry-run failed; see ${last_gpu_log}"
	fi
	mapfile -t configured_gpus < <(configured_gpu_list)
	status="$(vm_status || true)"
	if [[ "$status" == "running" ]]; then
		last_enumerated_gpu_count="$(qemu_monitor_gpu_count)"
	fi
	state_update "dry_run" "$CURRENT_PHASE" "success" \
		"read-only storage and static PCI checks completed; only logs and JSON state were written" \
		"$last_gpu_log" 0 0 0
	state_finalized=1
	log "Dry-run complete; runtime, storage mounts, PCI bindings, and VM configuration were unchanged"
}

on_exit() {
	local rc=$?

	trap - EXIT
	stop_progress_monitor
	if [[ "$rc" -ne 0 && "$state_initialized" -eq 1 && "$state_finalized" -eq 0 ]]; then
		state_update "exit" "$CURRENT_PHASE" "failed" \
			"${FINAL_MESSAGE:-startup workflow exited unexpectedly}" \
			"${last_start_log:-${last_gpu_log:-}}" "$rc" 0 0 || true
	fi
	exit "$rc"
}

main() {
	local status
	local cache_reason=""
	local bad_gpu=""

	parse_args "$@"
	[[ "$VMID" =~ ^[1-9][0-9]*$ ]] || die "invalid VMID: ${VMID}"
	[[ "$MAX_PRODUCTION_STARTS" =~ ^[12]$ ]] ||
		die "MAX_PRODUCTION_STARTS must be 1 or 2"
	[[ "$START_PROGRESS_INTERVAL" =~ ^[1-9][0-9]*$ ]] ||
		die "START_PROGRESS_INTERVAL must be a positive integer"

	CONF="${CONF_ROOT}/${VMID}.conf"
	LOCK_FILE="${LOCK_ROOT}/start-vm${VMID}.lock"

	[[ $EUID -eq 0 ]] || die "this script must run as root"
	require_cmd qm
	require_cmd pvesm
	require_cmd pvesh
	require_cmd timeout
	require_cmd flock
	require_cmd systemd-escape
	require_cmd systemctl
	require_cmd mountpoint
	require_cmd perl
	require_cmd sha256sum
	require_cmd hostname
	[[ -x "$GPU_TOOL" ]] || die "GPU tool is not executable: ${GPU_TOOL}"
	[[ -f "$CONF" ]] || die "VM config not found: ${CONF}"
	PVE_NODE="$(hostname)"
	resolve_start_timeout

	mkdir -p "$LOCK_ROOT"
	exec 9>"$LOCK_FILE"
	flock -n 9 || die "another startup/diagnostic job is active for VM ${VMID}"

	mkdir -p -m 700 "$RUN_ROOT"
	RUN_DIR="${RUN_ROOT}/vm${VMID}-$(date '+%F-%H%M%S-%N')"
	mkdir -m 700 "$RUN_DIR"
	REQUEST_ID="${RUN_DIR##*/}"
	log "Run logs: ${RUN_DIR}"
	load_revalidation_candidates

	CURRENT_PHASE="initialized"
	state_initialized=1
	state_update "init" "$CURRENT_PHASE" "in_progress" \
		"startup request accepted" "" 0 0 0

	if [[ "$DRY_RUN" -eq 1 ]]; then
		run_dry_run
		return 0
	fi

	status="$(vm_status || true)"
	if [[ "$status" == "running" ]]; then
		if [[ "$REVALIDATE_QUARANTINED" -eq 1 ]]; then
			CURRENT_PHASE="revalidation_requires_stopped_vm"
			die "--revalidate-quarantined requires VM ${VMID} to be stopped; refusing to stop a running VM automatically"
		fi
		GPU_SOURCE="current_running"
		collect_storage_state
		mapfile -t configured_gpus < <(configured_gpu_list)
		if [[ -z "$last_enumerated_gpu_count" ]]; then
			last_enumerated_gpu_count="$(qemu_monitor_gpu_count)"
		fi
		CURRENT_PHASE="already_running"
		if [[ "$last_enumerated_gpu_count" -ne ${#configured_gpus[@]} ]]; then
			state_update "already_running" "$CURRENT_PHASE" "running" \
				"VM is already running, but complete GPU enumeration is not verified; live configuration was not modified" \
				"" 0 0 0
			state_finalized=1
			warn "Current VM GPU enumeration is incomplete: configured=${#configured_gpus[@]}, QEMU-visible=${last_enumerated_gpu_count}"
			warn "The compacted configuration will be applied at the next stopped startup"
		elif [[ "$storage_all_ready" -ne 1 ]]; then
			state_update "already_running" "$CURRENT_PHASE" "running" \
				"VM and GPU enumeration are healthy, but configured storage is not fully ready; live configuration was not modified" \
				"" 0 0 0
			state_finalized=1
			warn "VM GPU enumeration is complete, but configured storage is not fully ready"
		else
			state_update "already_running" "$CURRENT_PHASE" "success" \
				"observed a healthy running VM with complete storage and QEMU GPU enumeration; live configuration was not modified" \
				"" 0 0 1
			state_finalized=1
			log "VM ${VMID} is already running with complete QEMU GPU enumeration; last_success was updated"
		fi
		return 0
	fi

	wait_for_vm_storage
	load_static_healthy_gpus ||
		die "static GPU inventory/health discovery failed"

	if [[ "$REVALIDATE_QUARANTINED" -eq 1 ]]; then
		cache_reason="explicit full quarantine revalidation requested"
	elif state_has_last_success; then
		mapfile -t cached_gpus < <(read_last_success_gpus)
		if arrays_equal cached_gpus static_healthy_gpus; then
			if apply_cached_gpu_config; then
				mapfile -t configured_gpus < <(configured_gpu_list)
				if production_start "last-success" "${#configured_gpus[@]}"; then
					finalize_success
					return 0
				fi
				if [[ "$last_start_failure_kind" == "orchestration_timeout" ]]; then
					die "production start exceeded the ${START_TIMEOUT}s orchestration deadline; PCI diagnosis would not make memory initialization faster"
				fi
				warn "Cached production start failed; switching to lightweight PCI diagnosis"
				run_gpu_diagnosis ||
					die "lightweight diagnosis failed after cached startup failure"
				if ((production_start_count < MAX_PRODUCTION_STARTS)); then
					if production_start "diagnosed-retry" "${#configured_gpus[@]}"; then
						finalize_success
						return 0
					fi
				fi
				handle_final_start_failure
			fi
			cache_reason="last-success configuration could not be applied"
		else
			cache_reason="healthy visible GPU set differs from last_success"
		fi
	else
		cache_reason="no verified last_success GPU configuration exists"
	fi

	warn "${cache_reason}; starting lightweight PCI diagnosis"
	run_gpu_diagnosis ||
		die "lightweight GPU diagnosis failed"
	if production_start "diagnosed" "${#configured_gpus[@]}"; then
		finalize_success
		return 0
	fi

	bad_gpu="$(extract_unique_fault_gpu "$last_start_log" || true)"
	if [[ -n "$bad_gpu" && "$production_start_count" -lt "$MAX_PRODUCTION_STARTS" ]]; then
		prepare_after_identified_failure "$bad_gpu" \
			"production QEMU log identified this device after lightweight validation" ||
			die "failed to quarantine and reconfigure after identifying ${bad_gpu}"
		if production_start "after-identified-quarantine" "${#configured_gpus[@]}"; then
			finalize_success
			return 0
		fi
	fi

	handle_final_start_failure
}

trap on_exit EXIT
main "$@"
