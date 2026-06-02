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
  local target_user shell_path home_dir
  target_user="$(yaml_get user.name ubuntu)"
  home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
  shell_path="$(yaml_get user.shell /usr/bin/zsh)"
  if [[ -x "$shell_path" && -n "$home_dir" ]] && id "$target_user" >/dev/null 2>&1; then
    chsh -s "$shell_path" "$target_user" || true
    sudo -u "$target_user" mkdir -p "$home_dir/.zsh"
    if [[ ! -d "$home_dir/.zsh/zsh-autocomplete/.git" ]]; then
      sudo -u "$target_user" git clone --depth 1 https://github.com/marlonrichert/zsh-autocomplete.git "$home_dir/.zsh/zsh-autocomplete" || true
    fi
    if [[ ! -f "$home_dir/.zsh/zsh-autosuggestions.zsh" ]]; then
      if [[ -d "$home_dir/.zsh/zsh-autosuggestions/.git" ]]; then
        cp "$home_dir/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" "$home_dir/.zsh/zsh-autosuggestions.zsh" || true
      else
        timeout 60 wget -q https://raw.staticdn.net/zsh-users/zsh-autosuggestions/master/zsh-autosuggestions.zsh -O "$home_dir/.zsh/zsh-autosuggestions.zsh" || true
      fi
    fi
    cat >"$home_dir/.zshrc" <<'EOF'
autoload -Uz promptinit
promptinit
PROMPT='%F{yellow}%~ # %f'

setopt histignorealldups sharehistory
bindkey -e
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

alias ls="ls --color"
alias gs="git status"
alias gb="git rev-parse --abbrev-ref HEAD"
alias gba="git -P branch"
alias gdp="git -P diff"
alias gdh="git diff HEAD^ HEAD"
alias gl="git log"
alias gn="git --no-pager log --pretty='format:%Cgreen[%h] %Cblue[%ai] %Creset[%an]%C(Red)%d %n  %Creset%s %n' -n5"
alias ga="git add"
alias gas="git add . && git status"
alias gc="git commit"
alias gk="git checkout"
alias gau="git add -u"
alias gcm="git commit -m"
alias gcan="git commit --amend --no-edit"
alias gp="git push"
alias gpf="git push -f"
alias gacp="git add -u && git commit --amend --no-edit && git push -f"
[[ -f ~/.gd.sh ]] && source ~/.gd.sh

alias ta="tmux a"
alias td="tmux detach"
alias tn="tmux new -s x"
alias tl="tmux ls"
alias ts="tmux select-pane -T"
alias tm="top -o %MEM -d 2 -c"
alias tc="top -o %CPU -d 2 -c"
alias k9="kill -9"
alias lt="ls -lt"
alias hi="hostname -i"

bindkey "^[[1;5C" forward-word
bindkey "^[[1;3C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[1~"   beginning-of-line
bindkey "^[[4~"   end-of-line
bindkey "^[[3~"   delete-char
bindkey "^[^[[3~" delete-word

if [[ -f ~/.zsh/zsh-autosuggestions.zsh ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#ff00ff"
  source ~/.zsh/zsh-autosuggestions.zsh
fi
if [[ -f ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]]; then
  source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh 2>/dev/null
  zstyle ':completion:*' list-colors '=*=96'
fi

if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
  . "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [[ -x "$HOME/miniconda3/bin/conda" ]]; then
  export PATH="$HOME/miniconda3/bin:$PATH"
fi
alias cda="conda activate ai"
alias cdd="conda deactivate"
if command -v conda >/dev/null 2>&1 && conda env list | awk '{print $1}' | grep -qx ai; then
  conda activate ai
fi

alias nu="gpustat -cpu -i -F -P"
alias nsd="nvidia-smi | grep Default"
export HF_ENDPOINT=https://hf-mirror.com
export REPOS=$HOME/repos
export DATA=/media/data1
export PATH=/usr/local/cuda/bin:$HOME/.local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}

ulimit -n 1048576 2>/dev/null || true
fpath+=~/.zfunc
autoload -Uz compinit
compinit
EOF
    cat >"$home_dir/.zshenv" <<'EOF'
skip_global_compinit=1
EOF
    chown "$target_user:$target_user" "$home_dir/.zshrc" "$home_dir/.zshenv"
  fi
}

configure_tmux() {
  local target_user home_dir
  target_user="$(yaml_get user.name ubuntu)"
  home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
  [[ -z "$home_dir" ]] && return
  sudo -u "$target_user" mkdir -p "$home_dir/.tmux/plugins" "$home_dir/.config/systemd/user"
  if [[ ! -d "$home_dir/.tmux/plugins/tpm/.git" ]]; then
    sudo -u "$target_user" git clone --depth 1 https://github.com/tmux-plugins/tpm "$home_dir/.tmux/plugins/tpm" || true
  fi
  if [[ ! -d "$home_dir/.tmux/plugins/tmux-resurrect/.git" ]]; then
    sudo -u "$target_user" git clone --depth 1 https://github.com/tmux-plugins/tmux-resurrect "$home_dir/.tmux/plugins/tmux-resurrect" || true
  fi
  cat >"$home_dir/.tmux.conf" <<'EOF'
unbind C-b
set -g prefix M-z
bind M-z send-prefix
bind r source-file ~/.tmux.conf \; display ".tmux.conf reloaded!"
set -g mouse on
set -g status-interval 1
set-option -g status-position bottom
set-option -g status-style bg=default
set-option -g status-left ""
set-option -g window-status-format ""
set-option -g window-status-separator ""
set -g window-status-current-format "#[fg=cyan] #{pane_title}: [#{pane_current_path}]"
set-option -g status-right "#[fg=cyan,bold] [ww%V.%w] %m-%d %H:%M:%S"
set -g pane-border-status top
set -g pane-border-lines heavy
set -g pane-border-style bg=default,fg=cyan
set -g pane-active-border-style bg=cyan,fg=black
setw -g pane-border-format ' #{pane_index}: [#{pane_current_path}] '
unbind -n a
unbind-key -T root MouseDrag1Pane
unbind-key -T copy-mode-vi MouseDrag1Pane
unbind-key -T copy-mode MouseDrag1Pane
set-option -g default-shell /usr/bin/zsh
set-option -g history-limit 100000
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @resurrect-hook-pre-restore-pane-processes 'tmux kill-session -t=0 2>/dev/null || true'
set -g @resurrect-processes '\
    ssh mongosh \
    "~npx->npx *" \
    "~npm->npm *" \
    "~python->python *" \
    "~docker->docker *" \
    "~gpustat->gpustat *" \
'
run '~/.tmux/plugins/tpm/tpm'
EOF
  chown "$target_user:$target_user" "$home_dir/.tmux.conf"
}

install_dotfiles() {
  local target_user home_dir gd_src
  target_user="$(yaml_get user.name ubuntu)"
  home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
  [[ -z "$home_dir" ]] && return
  gd_src="$(yaml_get dotfiles.gd_source /opt/bj123-setup/dotfiles/.gd.sh)"
  if [[ -f "$gd_src" ]]; then
    install -m 0644 -o "$target_user" -g "$target_user" "$gd_src" "$home_dir/.gd.sh"
  elif [[ ! -f "$home_dir/.gd.sh" ]]; then
    timeout 60 wget -q "$(yaml_get dotfiles.gd_url https://raw.staticdn.net/Hansimov/blog/main/docs/notes/scripts/.gd.sh)" -O "$home_dir/.gd.sh" || true
    chown "$target_user:$target_user" "$home_dir/.gd.sh" 2>/dev/null || true
  fi
  sudo -u "$target_user" mkdir -p "$home_dir/.pip"
  cat >"$home_dir/.pip/pip.conf" <<'EOF'
[global]
index-url = https://mirrors.ustc.edu.cn/pypi/simple

[install]
trusted-host = mirrors.ustc.edu.cn
EOF
cat >"$home_dir/.condarc" <<'EOF'
channels:
  - conda-forge
  - bioconda
  - nodefaults
custom_channels:
  conda-forge: https://mirrors.ustc.edu.cn/anaconda/cloud
  bioconda: https://mirrors.ustc.edu.cn/anaconda/cloud
show_channel_urls: true
EOF
  chown -R "$target_user:$target_user" "$home_dir/.pip" "$home_dir/.condarc"
  configure_zsh
  configure_tmux
}

install_conda() {
  [[ "$(yaml_get conda.install false)" == "true" ]] || return
  local target_user home_dir installer url python_version env_name
  target_user="$(yaml_get user.name ubuntu)"
  home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
  [[ -z "$home_dir" ]] && return
  url="$(yaml_get conda.installer_url https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh)"
  installer="/tmp/miniconda.sh"
  if [[ ! -x "$home_dir/miniconda3/bin/conda" ]]; then
    wget -O "$installer" "$url"
    sudo -u "$target_user" bash "$installer" -b -u -p "$home_dir/miniconda3"
  fi
  cat >"$home_dir/.condarc" <<'EOF'
channels:
  - conda-forge
  - bioconda
  - nodefaults
custom_channels:
  conda-forge: https://mirrors.ustc.edu.cn/anaconda/cloud
  bioconda: https://mirrors.ustc.edu.cn/anaconda/cloud
show_channel_urls: true
EOF
  chown "$target_user:$target_user" "$home_dir/.condarc"
  sudo -u "$target_user" "$home_dir/miniconda3/bin/conda" config --set show_channel_urls true || true
  env_name="$(yaml_get conda.env_name ai)"
  python_version="$(yaml_get conda.python_version 3.13)"
  if [[ "$(yaml_get conda.create_env true)" == "true" ]]; then
    if ! sudo -u "$target_user" "$home_dir/miniconda3/bin/conda" env list | awk '{print $1}' | grep -qx "$env_name"; then
      sudo -u "$target_user" "$home_dir/miniconda3/bin/conda" create -y -n "$env_name" "python=${python_version}" --override-channels -c https://mirrors.ustc.edu.cn/anaconda/cloud/conda-forge || true
    fi
  fi
  configure_zsh
}

install_python_tools() {
  [[ "$(yaml_get python_tools.install true)" == "true" ]] || return
  local target_user home_dir pip_bin env_name
  target_user="$(yaml_get user.name ubuntu)"
  home_dir="$(getent passwd "$target_user" | cut -d: -f6)"
  [[ -z "$home_dir" ]] && return
  DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv
  sudo -u "$target_user" python3 -m pip install --user -U pip pipreqs gpustat || true
  env_name="$(yaml_get conda.env_name ai)"
  if [[ -x "$home_dir/miniconda3/envs/${env_name}/bin/pip" ]]; then
    pip_bin="$home_dir/miniconda3/envs/${env_name}/bin/pip"
    sudo -u "$target_user" "$pip_bin" install -U pip pipreqs gpustat || true
  fi
}

install_docker() {
  [[ "$(yaml_get docker.install false)" == "true" ]] || return
  local target_user mirror http_proxy https_proxy no_proxy
  target_user="$(yaml_get user.name ubuntu)"
  mirror="$(yaml_get docker.repo_mirror https://mirrors.ustc.edu.cn/docker-ce)"
  DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  rm -f /etc/apt/keyrings/docker.gpg
  curl -fsSL "${mirror}/linux/ubuntu/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${mirror}/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" >/etc/apt/sources.list.d/docker.list
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  usermod -aG docker "$target_user" || true
  gpasswd -a "$target_user" docker || true
  mkdir -p /etc/docker
  python3 - <<'PY'
import json, pathlib
path = pathlib.Path("/etc/docker/daemon.json")
data = {}
if path.exists():
    try:
        data = json.loads(path.read_text())
    except Exception:
        data = {}
data.setdefault("registry-mirrors", [
    "https://docker.1ms.run",
    "https://docker.1panel.live",
    "https://docker.m.daocloud.io",
])
path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
  http_proxy="$(yaml_get docker.http_proxy "")"
  https_proxy="$(yaml_get docker.https_proxy "$http_proxy")"
  no_proxy="$(yaml_get docker.no_proxy localhost,127.0.0.1)"
  if [[ -n "$http_proxy" ]]; then
    mkdir -p /etc/systemd/system/docker.service.d
    cat >/etc/systemd/system/docker.service.d/proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=${http_proxy}"
Environment="HTTPS_PROXY=${https_proxy}"
Environment="NO_PROXY=${no_proxy}"
EOF
  fi
  systemctl daemon-reload
  systemctl enable --now docker
  systemctl restart docker
}

install_nvidia_container() {
  [[ "$(yaml_get nvidia_container.install false)" == "true" ]] || return
  local base_url
  command -v docker >/dev/null 2>&1 || install_docker
  if ! command -v docker >/dev/null 2>&1; then
    log "Docker is not installed; skip NVIDIA Container Toolkit"
    return
  fi
  if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA driver is not ready; skip NVIDIA Container Toolkit"
    return
  fi
  if [[ "$(yaml_get nvidia_container.use_ustc_mirror true)" == "true" ]]; then
    base_url="https://mirrors.ustc.edu.cn/libnvidia-container"
  else
    base_url="https://nvidia.github.io/libnvidia-container"
  fi
  rm -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL "${base_url}/gpgkey" | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL "${base_url}/stable/deb/nvidia-container-toolkit.list" | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' >/etc/apt/sources.list.d/nvidia-container-toolkit.list
  if [[ "$(yaml_get nvidia_container.use_ustc_mirror true)" == "true" ]]; then
    sed -i 's#nvidia.github.io#mirrors.ustc.edu.cn#g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
  fi
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-container-toolkit
  if command -v nvidia-ctk >/dev/null 2>&1; then
    nvidia-ctk runtime configure --runtime=docker
  fi
  systemctl daemon-reload
  systemctl restart docker
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
  label="$(yaml_get hdd.label data1)"
  mountpoint="$(yaml_get hdd.mountpoint /media/data1)"
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
  if run_stage dotfiles; then
    install_dotfiles
  fi
  if run_stage conda; then
    install_conda
  fi
  if run_stage python_tools; then
    install_python_tools
  fi
  if run_stage docker; then
    install_docker
  fi
  if run_stage nvidia_container; then
    install_nvidia_container
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
