#!/bin/bash

# ============================================================
# Boot script for tmux-restore.service
# Run with: /bin/bash -l ~/run_at_boot.sh
# ============================================================

# Initialize conda environment
CONDA_BASE="$HOME/miniconda3"
CONDA_ENV="ai"

# Source conda
if [ -f "$CONDA_BASE/etc/profile.d/conda.sh" ]; then
    . "$CONDA_BASE/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV"
else
    echo "ERROR: conda.sh not found at $CONDA_BASE"
fi

# Ensure PATH includes conda env binaries
export PATH="$CONDA_BASE/envs/$CONDA_ENV/bin:$PATH"

# Helper function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================================
# 1. Start Xvfb (virtual framebuffer)
# ============================================================
log "RUN: Xvfb"
if command -v Xvfb &>/dev/null; then
    Xvfb -ac :99 -screen 0 1280x1024x16 &
else
    log "WARN: Xvfb not found, skipping"
fi

# ============================================================
# 2. IPv6 route setup (requires sudo NOPASSWD in sudoers)
# ============================================================
log "RUN: webu.ipv6.route"
PYTHON_BIN="$CONDA_BASE/envs/$CONDA_ENV/bin/python"
if [ -x "$PYTHON_BIN" ]; then
    sudo "$PYTHON_BIN" -m webu.ipv6.route || log "WARN: webu.ipv6.route failed (check sudoers NOPASSWD)"
else
    log "WARN: Python not found at $PYTHON_BIN"
fi

# ============================================================
# 3. Set file descriptor limit
# ============================================================
log "RUN: ulimit -n 1048576"
ulimit -n 1048576 2>/dev/null || log "WARN: Failed to set ulimit"

# ============================================================
# 4. GPU power and fan settings (requires sudo NOPASSWD)
# ============================================================
log "RUN: set GPU power limit and fans full speed"
GPU_POW="$CONDA_BASE/envs/$CONDA_ENV/bin/gpu_pow"
GPU_FAN="$CONDA_BASE/envs/$CONDA_ENV/bin/gpu_fan"

# if [ -x "$GPU_POW" ]; then
#     "$GPU_POW" -pm a:1 && "$GPU_POW" -pl "a:160" || log "WARN: gpu_pow failed"
# else
#     log "WARN: gpu_pow not found at $GPU_POW"
# fi

# if [ -x "$GPU_FAN" ]; then
#     "$GPU_FAN" -cs a:1 && "$GPU_FAN" -fs "a:100" || log "WARN: gpu_fan failed"
# else
#     log "WARN: gpu_fan not found at $GPU_FAN"
# fi

log "Boot script completed"
exit 0
