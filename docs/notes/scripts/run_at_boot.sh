#!/bin/zsh

echo "=========================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running boot tasks..."
echo "=========================================="

# Start Xvfb (virtual framebuffer for headless GUI)
echo "RUN: Xvfb"
Xvfb -ac :99 -screen 0 1280x1024x16 &

# IPv6 route setup
echo "RUN: webu.ipv6.route"
echo $SUDOPASS | sudo -S env "PATH=$PATH" python -m webu.ipv6.route

# Set file descriptor limit
echo "RUN: ulimit -n 1048576"
ulimit -n 1048576

# Keep the script running with an interactive shell
# This ensures tmux-resurrect sees "run_at_boot.sh" as the running process
# and will restore it on next boot

echo "=========================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Boot tasks completed! Press Ctrl+C to exit, or keep this pane open for auto-restore on reboot."

# Use a read loop to keep the script alive while allowing interaction
while true; do
    read -r cmd
    if [[ -n "$cmd" ]]; then
        eval "$cmd"
    fi
done
