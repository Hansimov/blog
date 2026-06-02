#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-/opt/bj123-setup/setup_ubuntu.yaml}"
LOG_FILE="/var/log/setup_ubuntu.log"

exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
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

install_packages() {
  mapfile -t pkgs < <(yaml_get packages.base "")
  if [[ "${#pkgs[@]}" -gt 0 ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${pkgs[@]}"
  fi
}

configure_apt_sources() {
  local mirror
  mirror="$(yaml_get system.apt_mirror "")"
  [[ -z "$mirror" ]] && return
  if [[ -f /etc/apt/sources.list ]]; then
    sed -i "s@http://.*archive.ubuntu.com@${mirror}@g; s@https://.*archive.ubuntu.com@${mirror}@g; s@http://security.ubuntu.com@${mirror}@g; s@https://security.ubuntu.com@${mirror}@g" /etc/apt/sources.list
    sed -i 's@http://@https://@g' /etc/apt/sources.list
  fi
}

configure_git() {
  local user email http_proxy https_proxy target_user home_dir
  target_user="$(yaml_get user.name ubuntu)"
  home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
  user="$(yaml_get git.user_name "")"
  email="$(yaml_get git.user_email "")"
  http_proxy="$(yaml_get git.http_proxy "")"
  https_proxy="$(yaml_get git.https_proxy "")"
  [[ -z "$home_dir" ]] && return
  sudo -u "$target_user" git config --global user.name "$user"
  sudo -u "$target_user" git config --global user.email "$email"
  [[ -n "$http_proxy" ]] && sudo -u "$target_user" git config --global http.proxy "$http_proxy"
  [[ -n "$https_proxy" ]] && sudo -u "$target_user" git config --global https.proxy "$https_proxy"
  git lfs install --system || true
}

configure_zsh() {
  local target_user shell_path
  target_user="$(yaml_get user.name ubuntu)"
  shell_path="$(yaml_get user.shell /usr/bin/zsh)"
  if [[ -x "$shell_path" ]] && id "$target_user" >/dev/null 2>&1; then
    chsh -s "$shell_path" "$target_user" || true
    sudo -u "$target_user" touch "/home/${target_user}/.zshrc"
    if ! grep -q "PROMPT='%F{yellow}%~ # %f'" "/home/${target_user}/.zshrc"; then
      cat >>"/home/${target_user}/.zshrc" <<'EOF'
PROMPT='%F{yellow}%~ # %f'
bindkey "^[[1;5C" forward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[1~"   beginning-of-line
bindkey "^[[4~"   end-of-line
bindkey "^[[3~"   delete-char
bindkey "^[^[[3~" delete-word
EOF
      chown "$target_user:$target_user" "/home/${target_user}/.zshrc"
    fi
  fi
}

install_tailscale() {
  [[ "$(yaml_get tailscale.install false)" != "true" ]] && return
  if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  systemctl enable --now tailscaled
  local auth_key
  auth_key="$(yaml_get tailscale.auth_key "")"
  if [[ "$(yaml_get tailscale.up false)" == "true" ]]; then
    if [[ -n "$auth_key" ]]; then
      tailscale up --auth-key "$auth_key"
    else
      tailscale up
    fi
  fi
}

install_v2ray() {
  [[ "$(yaml_get v2ray.install true)" != "true" ]] && return
  local script config_src config_dst
  script="$(yaml_get v2ray.install_script /opt/bj123-setup/v2ray-install-release.sh)"
  config_src="$(yaml_get v2ray.config_src /opt/bj123-setup/v2ray/config.json)"
  config_dst="$(yaml_get v2ray.config_dst /usr/local/etc/v2ray/config.json)"
  if [[ -x "$script" ]]; then
    "$script" || true
  fi
  if [[ "$(yaml_get v2ray.install_dat true)" == "true" ]]; then
    mkdir -p /usr/local/share/v2ray
    timeout 60 wget -q https://githubfast.com/v2fly/geoip/releases/latest/download/geoip.dat -O /usr/local/share/v2ray/geoip.dat || true
    timeout 60 wget -q https://githubfast.com/v2fly/domain-list-community/releases/latest/download/dlc.dat -O /usr/local/share/v2ray/geosite.dat || true
  fi
  if [[ -f "$config_src" ]]; then
    mkdir -p "$(dirname "$config_dst")"
    install -m 0644 "$config_src" "$config_dst"
  fi
  while IFS=$'\t' read -r name src dst service; do
    [[ -z "$name" ]] && continue
    if [[ -f "$src" ]]; then
      mkdir -p "$(dirname "$dst")"
      install -m 0644 "$src" "$dst"
      systemctl enable --now "$service" || true
    fi
  done < <(python3 - "$CONFIG" <<'PY'
import sys, yaml
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
for item in (((data.get("v2ray") or {}).get("extra_configs")) or []):
    name = str(item.get("name", "") or "")
    if not name:
        continue
    src = str(item.get("src", f"/opt/bj123-setup/v2ray/{name}.json"))
    dst = str(item.get("dst", f"/usr/local/etc/v2ray/{name}.json"))
    service = str(item.get("service", f"v2ray@{name}"))
    print("\t".join([name, src, dst, service]))
PY
  )
  if [[ "$(yaml_get v2ray.enable_service true)" == "true" ]]; then
    systemctl enable --now v2ray || true
  fi
}

mount_hdd() {
  [[ "$(yaml_get hdd.enabled false)" == "true" ]] || return
  local dev part fs label mountpoint uuid existing_fs existing_label
  dev="$(yaml_get hdd.device /dev/sdb)"
  part="$(yaml_get hdd.partition /dev/sdb1)"
  fs="$(yaml_get hdd.filesystem ext4)"
  label="$(yaml_get hdd.label data)"
  mountpoint="$(yaml_get hdd.mountpoint /media/data)"
  if mountpoint -q "$mountpoint"; then
    log "HDD already mounted at ${mountpoint}"
    return
  fi
  if [[ ! -b "$dev" ]]; then
    log "HDD device ${dev} is not present; skip guest HDD mount"
    return
  fi
  if [[ "$(findmnt -no SOURCE / 2>/dev/null)" == "$dev"* ]]; then
    log "Refusing to format root disk ${dev}"
    return 1
  fi
  existing_fs="$(blkid -s TYPE -o value "$part" 2>/dev/null || true)"
  existing_label="$(blkid -s LABEL -o value "$part" 2>/dev/null || true)"
  if [[ "$existing_fs" == "$fs" && "$existing_label" == "$label" ]]; then
    log "HDD partition ${part} already formatted as ${fs} with label ${label}; skip format"
  elif [[ "$(yaml_get hdd.wipe_existing false)" == "true" || ! -b "$part" ]]; then
    umount "$part" >/dev/null 2>&1 || true
    wipefs -a "$dev"
    parted -s "$dev" mklabel gpt
    parted -s "$dev" mkpart primary "$fs" 0% 100%
    partprobe "$dev" || true
    udevadm settle
    mkfs -t "$fs" -F -L "$label" "$part"
  fi
  mkdir -p "$mountpoint"
  uuid="$(blkid -s UUID -o value "$part")"
  grep -q " ${mountpoint} " /etc/fstab || echo "UUID=${uuid} ${mountpoint} ${fs} defaults,nofail 0 2" >>/etc/fstab
  mountpoint -q "$mountpoint" || mount "$mountpoint"
  log "HDD mounted at ${mountpoint}"
}

install_nvidia_driver() {
  [[ "$(yaml_get nvidia.install_driver false)" == "true" ]] || return
  if ! lspci -nn | grep -Eq 'NVIDIA.*(VGA|3D|Display)|VGA.*NVIDIA|3D.*NVIDIA|Display.*NVIDIA'; then
    log "No NVIDIA GPU visible in guest; skip NVIDIA driver"
    return
  fi
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA driver already works"
    return
  fi
  DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-drivers-common
  local pkg
  pkg="$(yaml_get nvidia.driver_package auto)"
  if [[ "$pkg" == "auto" || -z "$pkg" ]]; then
    pkg="$(ubuntu-drivers devices 2>/dev/null | sed -n 's/.*driver *: *\\([^ ]*\\).*recommended.*/\\1/p' | head -1)"
  fi
  [[ -z "$pkg" ]] && pkg="nvidia-driver-535"
  log "Installing NVIDIA driver package: ${pkg}"
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
}

install_cuda() {
  [[ "$(yaml_get nvidia.install_cuda false)" == "true" ]] || return
  if command -v nvcc >/dev/null 2>&1; then
    log "CUDA nvcc already installed: $(command -v nvcc)"
    return
  fi
  if ! lspci -nn | grep -Eq 'NVIDIA.*(VGA|3D|Display)|VGA.*NVIDIA|3D.*NVIDIA|Display.*NVIDIA'; then
    log "No NVIDIA GPU visible in guest; skip CUDA"
    return
  fi
  local method package keyring_url tmpdeb
  method="$(yaml_get nvidia.cuda_method nvidia_repo)"
  package="$(yaml_get nvidia.cuda_package cuda-toolkit-13-0)"
  if [[ "$method" == "apt" ]]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-cuda-toolkit
  else
    keyring_url="$(yaml_get nvidia.cuda_keyring_url)"
    tmpdeb="/tmp/cuda-keyring.deb"
    if [[ ! -f /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list ]]; then
      wget -O "$tmpdeb" "$keyring_url"
      dpkg -i "$tmpdeb"
      apt-get update
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
  fi
  cat >/etc/profile.d/cuda.sh <<'EOF'
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}
EOF
}

install_desktop() {
  [[ "$(yaml_get desktop.install false)" != "true" ]] && return
  local package
  package="$(yaml_get desktop.package ubuntu-desktop-minimal)"
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
}

main() {
  log "setup_ubuntu started with config=${CONFIG}"
  ensure_yaml
  if run_stage apt_sources; then
    configure_apt_sources
  fi
  apt-get update
  if run_stage base_packages; then
    install_packages
  fi
  if run_stage qemu_guest_agent; then
    systemctl enable --now qemu-guest-agent
  fi
  if run_stage ssh; then
    systemctl enable --now ssh
  fi
  if run_stage tailscale; then
    install_tailscale
  fi
  if run_stage v2ray; then
    install_v2ray
  fi
  if run_stage hdd_mount; then
    mount_hdd
  fi
  if run_stage nvidia_driver; then
    install_nvidia_driver
  fi
  if run_stage cuda; then
    install_cuda
  fi
  if run_stage git; then
    configure_git
  fi
  if run_stage zsh; then
    configure_zsh
  fi
  if run_stage desktop; then
    install_desktop
  fi
  log "setup_ubuntu finished"
}

main "$@"
