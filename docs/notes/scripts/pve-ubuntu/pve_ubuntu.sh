#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-$(dirname "$0")/pve_ubuntu.yaml}"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/var/log/pve_ubuntu.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root on the PVE host." >&2
    exit 1
  fi
}

ensure_yaml() {
  if python3 - <<'PY' >/dev/null 2>&1
import yaml
PY
  then
    return
  fi
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3-yaml
}

yaml_get() {
  local path="$1"
  local default="${2:-}"
  python3 - "$CONFIG" "$path" "$default" <<'PY'
import sys, yaml
cfg_path, key_path, default = sys.argv[1:4]
with open(cfg_path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
cur = data
for part in key_path.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print(default)
        sys.exit(0)
if cur is None:
    print(default)
elif isinstance(cur, bool):
    print("true" if cur else "false")
elif isinstance(cur, list):
    print("\n".join(str(x) for x in cur))
else:
    print(cur)
PY
}

stage_mode() {
  local stage="$1"
  local mode
  mode="$(yaml_get "stages.${stage}.mode" "")"
  if [[ -z "$mode" ]]; then
    mode="$(yaml_get "global.mode" "confirm")"
  fi
  printf '%s' "$mode"
}

run_stage() {
  local stage="$1"
  local mode
  mode="$(stage_mode "$stage")"
  case "$mode" in
    auto) return 0 ;;
    manual|skip) log "skip stage ${stage} (mode=${mode})"; return 1 ;;
    confirm)
      read -r -p "Run stage ${stage}? [y/N] " answer
      [[ "${answer,,}" == y* ]]
      ;;
    *) log "skip stage ${stage} (unknown mode=${mode})"; return 1 ;;
  esac
}

install_host_packages() {
  DEBIAN_FRONTEND=noninteractive apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3-yaml sshpass wget curl genisoimage parted e2fsprogs
}

copy_iso_from_source() {
  local src_ip src_user src_pass src_iso iso_dir dst_iso
  src_ip="$(yaml_get source.ip)"
  src_user="$(yaml_get source.user root)"
  src_pass="$(yaml_get source.password)"
  src_iso="$(yaml_get source.iso_path)"
  iso_dir="$(yaml_get vm.iso_storage_dir /var/lib/vz/template/iso)"
  dst_iso="${iso_dir}/$(basename "$src_iso")"
  mkdir -p "$iso_dir"
  if [[ -f "$dst_iso" ]]; then
    log "ISO already exists: ${dst_iso}"
    return
  fi
  log "copy ISO from ${src_user}@${src_ip}:${src_iso} to ${dst_iso}"
  sshpass -p "$src_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${src_user}@${src_ip}:${src_iso}" "$dst_iso"
}

copy_v2ray_config_from_source() {
  local src_ip src_user src_pass src_dir workdir dst_dir
  src_ip="$(yaml_get source.ip)"
  src_user="$(yaml_get source.user root)"
  src_pass="$(yaml_get source.password)"
  src_dir="$(yaml_get source.v2ray_config_dir /usr/local/etc/v2ray)"
  workdir="$(yaml_get global.workdir /root/pve-ubuntu)"
  dst_dir="${workdir}/v2ray"
  mkdir -p "$dst_dir"
  log "copy v2ray config from ${src_user}@${src_ip}:${src_dir}"
  sshpass -p "$src_pass" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${src_user}@${src_ip}:${src_dir}/"* "$dst_dir/" || true
}

download_cloud_image() {
  local url img
  url="$(yaml_get vm.cloud_image_url)"
  img="$(yaml_get vm.cloud_image_path)"
  mkdir -p "$(dirname "$img")"
  if [[ -s "$img" ]]; then
    log "cloud image already exists: ${img}"
    return
  fi
  log "download cloud image: ${url}"
  wget -O "${img}.tmp" "$url"
  mv "${img}.tmp" "$img"
}

password_hash() {
  local password="$1"
  openssl passwd -6 "$password"
}

write_b64_file_entry() {
  local path="$1"
  local dst="$2"
  local perms="${3:-0644}"
  [[ -f "$path" ]] || return
  {
    echo "  - path: ${dst}"
    echo "    permissions: '${perms}'"
    echo "    encoding: b64"
    echo "    content: $(base64 -w0 "$path")"
  } >>"$USER_DATA"
}

create_cloud_init_seed() {
  local workdir seed_dir user_data meta_data network_config cidata_iso vmid hostname username password full_name timezone ssh_auth ip prefix gateway dns password_hash_value
  workdir="$(yaml_get global.workdir /root/pve-ubuntu)"
  vmid="$(yaml_get vm.id)"
  hostname="$(yaml_get vm.hostname)"
  username="$(yaml_get ubuntu.user)"
  password="$(yaml_get ubuntu.password)"
  full_name="$(yaml_get ubuntu.full_name "$username")"
  timezone="$(yaml_get ubuntu.timezone Asia/Shanghai)"
  ssh_auth="$(yaml_get ubuntu.ssh_password_auth true)"
  ip="$(yaml_get network.ipv4)"
  prefix="$(yaml_get network.prefix 24)"
  gateway="$(yaml_get network.gateway4)"
  mapfile -t dns < <(yaml_get network.dns "192.168.31.1")
  password_hash_value="$(password_hash "$password")"
  seed_dir="${workdir}/seed-${vmid}"
  cidata_iso="$(yaml_get vm.iso_storage_dir /var/lib/vz/template/iso)/${hostname}-cidata.iso"
  mkdir -p "$seed_dir" "$(dirname "$cidata_iso")"

  USER_DATA="${seed_dir}/user-data"
  meta_data="${seed_dir}/meta-data"
  network_config="${seed_dir}/network-config"

  cat >"$USER_DATA" <<EOF
#cloud-config
hostname: ${hostname}
manage_etc_hosts: true
timezone: ${timezone}
locale: $(yaml_get ubuntu.locale en_US.UTF-8)
ssh_pwauth: ${ssh_auth}
disable_root: false
users:
  - default
  - name: ${username}
    gecos: ${full_name}
    shell: /bin/bash
    lock_passwd: false
    passwd: '${password_hash_value}'
    groups: [adm, cdrom, dip, lxd, plugdev, sudo]
    sudo: ['ALL=(ALL) ALL']
package_update: true
packages:
  - openssh-server
  - qemu-guest-agent
  - python3-yaml
write_files:
EOF
  write_b64_file_entry "${BASE_DIR}/setup_ubuntu.sh" "/opt/bj123-setup/setup_ubuntu.sh" "0755"
  write_b64_file_entry "${BASE_DIR}/setup_ubuntu.yaml" "/opt/bj123-setup/setup_ubuntu.yaml" "0644"
  write_b64_file_entry "${BASE_DIR}/v2ray-install-release.sh" "/opt/bj123-setup/v2ray-install-release.sh" "0755"
  if [[ -f "${BASE_DIR}/dotfiles/.gd.sh" ]]; then
    write_b64_file_entry "${BASE_DIR}/dotfiles/.gd.sh" "/opt/bj123-setup/dotfiles/.gd.sh" "0644"
  fi
  write_b64_file_entry "${workdir}/v2ray/config.json" "/opt/bj123-setup/v2ray/config.json" "0644"
  write_b64_file_entry "${workdir}/v2ray/new.json" "/opt/bj123-setup/v2ray/new.json" "0644"
  cat >>"$USER_DATA" <<EOF
runcmd:
  - systemctl enable --now ssh
  - systemctl enable --now qemu-guest-agent
  - chmod +x /opt/bj123-setup/setup_ubuntu.sh
  - [ bash, /opt/bj123-setup/setup_ubuntu.sh, /opt/bj123-setup/setup_ubuntu.yaml ]
EOF

  cat >"$meta_data" <<EOF
instance-id: ${hostname}-${vmid}
local-hostname: ${hostname}
EOF

  cat >"$network_config" <<EOF
version: 2
ethernets:
  lan0:
    match:
      name: "en*"
    dhcp4: false
    addresses:
      - ${ip}/${prefix}
    routes:
      - to: default
        via: ${gateway}
    nameservers:
      addresses: [$(printf '%s,' "${dns[@]}" | sed 's/,$//')]
EOF
  genisoimage -output "$cidata_iso" -volid cidata -joliet -rock "$USER_DATA" "$meta_data" "$network_config"
  log "cloud-init seed created: ${cidata_iso}"
}

create_vm() {
  local vmid name storage bridge memory cores sockets cpu machine bios ostype vga disk_size img overwrite cidata_iso
  vmid="$(yaml_get vm.id)"
  name="$(yaml_get vm.name)"
  storage="$(yaml_get vm.storage local-lvm)"
  bridge="$(yaml_get vm.bridge vmbr0)"
  memory="$(yaml_get vm.memory_mib 65536)"
  cores="$(yaml_get vm.cores 16)"
  sockets="$(yaml_get vm.sockets 1)"
  cpu="$(yaml_get vm.cpu host)"
  machine="$(yaml_get vm.machine q35)"
  bios="$(yaml_get vm.bios ovmf)"
  ostype="$(yaml_get vm.ostype l26)"
  vga="$(yaml_get vm.vga std)"
  disk_size="$(yaml_get vm.disk_size 256G)"
  img="$(yaml_get vm.cloud_image_path)"
  overwrite="$(yaml_get vm.overwrite_existing false)"
  cidata_iso="$(yaml_get vm.iso_storage_dir /var/lib/vz/template/iso)/$(yaml_get vm.hostname)-cidata.iso"

  if qm status "$vmid" >/dev/null 2>&1; then
    if [[ "$overwrite" != "true" ]]; then
      log "VM ${vmid} already exists; overwrite_existing=false"
      return
    fi
    qm stop "$vmid" --skiplock 1 || true
    qm destroy "$vmid" --purge 1 --destroy-unreferenced-disks 1
  fi

  qm create "$vmid" \
    --name "$name" \
    --memory "$memory" \
    --cores "$cores" \
    --sockets "$sockets" \
    --cpu "$cpu" \
    --machine "$machine" \
    --bios "$bios" \
    --ostype "$ostype" \
    --agent enabled=1 \
    --scsihw virtio-scsi-single \
    --net0 "virtio,bridge=${bridge}"

  qm importdisk "$vmid" "$img" "$storage"
  qm set "$vmid" --vga "$vga"
  qm set "$vmid" --scsi0 "${storage}:vm-${vmid}-disk-0,discard=on,ssd=1,iothread=1"
  qm set "$vmid" --efidisk0 "${storage}:0,efitype=4m,pre-enrolled-keys=0"
  qm set "$vmid" --ide2 "local:iso/$(basename "$cidata_iso"),media=cdrom"
  qm set "$vmid" --boot "order=scsi0;ide2;net0"
  qm set "$vmid" --serial0 socket
  qm resize "$vmid" scsi0 "$disk_size"
  if [[ "$(yaml_get vm.start_on_boot false)" == "true" ]]; then
    qm set "$vmid" --onboot 1
  fi
  log "VM ${vmid}/${name} created"
}

configure_gpu_passthrough() {
  if [[ "$(yaml_get gpu_passthrough.enabled false)" != "true" ]]; then
    log "gpu_passthrough.enabled=false; skip host VFIO changes"
    return
  fi
  local ids vmid idx changed arg current grub_line spec
  vmid="$(yaml_get vm.id)"
  ids="$(yaml_get gpu_passthrough.vfio_ids "" | paste -sd, -)"
  changed=0
  if [[ -f /etc/kernel/cmdline ]]; then
    current="$(cat /etc/kernel/cmdline)"
    while read -r arg; do
      [[ -z "$arg" ]] && continue
      if ! grep -qw -- "$arg" <<<"$current"; then
        sed -i "s/$/ ${arg}/" /etc/kernel/cmdline
        current="${current} ${arg}"
        changed=1
      fi
    done < <(yaml_get gpu_passthrough.kernel_args "intel_iommu=on"$'\n'"iommu=pt")
  elif [[ -f /etc/default/grub ]]; then
    grub_line="$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub || true)"
    current="${grub_line#*=}"
    current="${current%\"}"
    current="${current#\"}"
    while read -r arg; do
      [[ -z "$arg" ]] && continue
      if ! grep -qw -- "$arg" <<<"$current"; then
        current="${current} ${arg}"
        changed=1
      fi
    done < <(yaml_get gpu_passthrough.kernel_args "intel_iommu=on"$'\n'"iommu=pt")
    if [[ $changed -eq 1 ]]; then
      if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${current# }\"|" /etc/default/grub
      else
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${current# }\"" >>/etc/default/grub
      fi
      update-grub
    fi
  else
    echo "Neither /etc/kernel/cmdline nor /etc/default/grub exists; cannot set IOMMU kernel args" >&2
    exit 1
  fi
  cat >/etc/modules-load.d/vfio.conf <<'EOF'
vfio
vfio_pci
vfio_iommu_type1
EOF
  cat >/etc/modprobe.d/blacklist-nvidia-passthrough.conf <<'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
EOF
  if [[ -n "$ids" ]]; then
    {
      echo "options vfio-pci ids=${ids}"
      echo "softdep snd_hda_intel pre: vfio-pci"
    } >/etc/modprobe.d/vfio.conf
  fi
  proxmox-boot-tool refresh || true
  update-initramfs -u -k all
  qm stop "$vmid" --skiplock 1 >/dev/null 2>&1 || true
  qm set "$vmid" --vga "$(yaml_get vm.vga std)"
  idx=0
  while read -r pci; do
    [[ -z "$pci" ]] && continue
    if [[ "$pci" == *,* ]]; then
      spec="$pci"
      [[ "$spec" != *pcie=* ]] && spec="${spec},pcie=1"
    else
      spec="${pci},pcie=1"
    fi
    qm set "$vmid" "--hostpci${idx}" "$spec"
    idx=$((idx + 1))
  done < <(yaml_get gpu_passthrough.pci_addresses "")
  if qm config "$vmid" | grep -q '^efidisk0: .*pre-enrolled-keys=1'; then
    log "VM ${vmid} still has OVMF secure boot keys enrolled; recreate efidisk0 manually if NVIDIA module signing blocks driver loading"
  fi
  if [[ $changed -eq 1 || "$(lspci -Dnnk | awk '/NVIDIA/{n=1} n&&/Kernel driver in use/{print; n=0}' | grep -c vfio-pci || true)" -eq 0 ]]; then
    touch /run/pve_ubuntu_reboot_required
    log "GPU passthrough host configuration changed; reboot required"
  fi
  log "GPU passthrough configured; reboot qve before starting GPU workload"
}

configure_hdd_storage() {
  [[ "$(yaml_get hdd.enabled false)" == "true" ]] || return 0
  local disk part fs label mountpoint storage uuid existing_fs existing_label
  disk="$(yaml_get hdd.disk_by_id)"
  part="$(yaml_get hdd.partition)"
  fs="$(yaml_get hdd.filesystem ext4)"
  label="$(yaml_get hdd.label hdd8t)"
  mountpoint="$(yaml_get hdd.mountpoint /mnt/hdd8t)"
  storage="$(yaml_get hdd.storage_name hdd8t)"

  if mountpoint -q "$mountpoint" && pvesm status | awk '{print $1}' | grep -qx "$storage"; then
    log "HDD storage ${storage} already mounted at ${mountpoint}"
    return
  fi

  if [[ ! -b "$disk" ]]; then
    echo "HDD disk not found: $disk" >&2
    exit 1
  fi
  if [[ "$(yaml_get hdd.wipe_existing false)" != "true" ]] && [[ ! -b "$part" ]]; then
    echo "HDD partition missing and hdd.wipe_existing=false: $part" >&2
    exit 1
  fi

  existing_fs="$(blkid -s TYPE -o value "$part" 2>/dev/null || true)"
  existing_label="$(blkid -s LABEL -o value "$part" 2>/dev/null || true)"
  if [[ "$existing_fs" == "$fs" && "$existing_label" == "$label" ]]; then
    log "HDD partition ${part} already formatted as ${fs} with label ${label}; skip format"
  elif [[ "$(yaml_get hdd.wipe_existing false)" == "true" ]]; then
    log "Formatting HDD ${disk} as ${fs}; existing data will be destroyed"
    umount "$part" >/dev/null 2>&1 || true
    wipefs -a "$disk"
    parted -s "$disk" mklabel gpt
    parted -s "$disk" mkpart primary "$fs" 0% 100%
    partprobe "$disk" || true
    udevadm settle
    mkfs -t "$fs" -F -L "$label" "$part"
  fi

  mkdir -p "$mountpoint"
  uuid="$(blkid -s UUID -o value "$part")"
  grep -q " ${mountpoint} " /etc/fstab || echo "UUID=${uuid} ${mountpoint} ${fs} defaults,nofail 0 2" >>/etc/fstab
  mountpoint -q "$mountpoint" || mount "$mountpoint"
  if ! pvesm status | awk '{print $1}' | grep -qx "$storage"; then
    pvesm add dir "$storage" --path "$mountpoint" --content "$(yaml_get hdd.storage_content images,backup,iso)" --is_mountpoint 1
  fi
  log "HDD storage ${storage} ready at ${mountpoint}"
}

attach_hdd_to_vm() {
  [[ "$(yaml_get hdd.vm_disk.enabled false)" == "true" ]] || return 0
  local vmid storage bus size opts
  vmid="$(yaml_get vm.id)"
  storage="$(yaml_get hdd.storage_name hdd8t)"
  bus="$(yaml_get hdd.vm_disk.bus scsi1)"
  size="$(yaml_get hdd.vm_disk.size 7000)"
  if qm config "$vmid" | grep -q "^${bus}:"; then
    log "VM ${vmid} already has ${bus}; skip HDD attach"
    return
  fi
  opts="${storage}:${size},format=$(yaml_get hdd.vm_disk.format raw)"
  [[ "$(yaml_get hdd.vm_disk.iothread true)" == "true" ]] && opts="${opts},iothread=1"
  [[ "$(yaml_get hdd.vm_disk.discard false)" == "true" ]] && opts="${opts},discard=on"
  [[ "$(yaml_get hdd.vm_disk.ssd false)" == "true" ]] && opts="${opts},ssd=1"
  qm set "$vmid" "--${bus}" "$opts"
  log "Attached HDD-backed disk to VM ${vmid}: ${bus}=${opts}"
}

start_vm() {
  local vmid
  vmid="$(yaml_get vm.id)"
  if [[ -f /run/pve_ubuntu_reboot_required ]]; then
    log "Host reboot is required before starting VM ${vmid}; skip start"
    return
  fi
  if qm status "$vmid" | grep -q 'status: running'; then
    log "VM ${vmid} already running"
    return
  fi
  qm start "$vmid"
  log "VM ${vmid} started"
}

main() {
  need_root
  ensure_yaml
  log "pve_ubuntu started with config=${CONFIG}"
  if run_stage install_host_packages; then install_host_packages; fi
  if run_stage copy_iso; then copy_iso_from_source; fi
  if run_stage copy_v2ray_config; then copy_v2ray_config_from_source; fi
  download_cloud_image
  create_cloud_init_seed
  if run_stage create_vm; then create_vm; fi
  if run_stage hdd_storage; then configure_hdd_storage; fi
  if run_stage attach_hdd; then attach_hdd_to_vm; fi
  if run_stage gpu_passthrough; then configure_gpu_passthrough; fi
  if run_stage start_vm; then start_vm; fi
  log "pve_ubuntu finished"
}

main "$@"
