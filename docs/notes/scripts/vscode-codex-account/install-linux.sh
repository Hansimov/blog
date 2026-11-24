#!/usr/bin/env bash
# Run on the Remote SSH host, as the user who runs VS Code Server.
set -euo pipefail

action=${1:-install}
directory=${2:-"$HOME/.local/bin"}
if [[ $# -gt 2 || "$directory" != /* || "$(uname -s)" != Linux ]]; then
    echo "Usage on Linux: bash install-linux.sh {install|check|uninstall} [absolute-bin-directory]" >&2
    exit 2
fi
target="$directory/vscodex-app-server"
marker='# Managed by vscode-codex-account (Linux).'

managed() {
    [[ -f "$target" && ! -L "$target" && "$(sed -n '2p' -- "$target")" == "$marker" ]]
}

case "$action" in
    uninstall)
        if [[ ! -e "$target" && ! -L "$target" ]]; then exit 0; fi
        managed || { echo 'Refusing to remove an unmanaged command.' >&2; exit 1; }
        rm -- "$target"
        exit 0
        ;;
    check)
        managed && [[ -x "$target" ]] || { echo 'Managed executable is not installed.' >&2; exit 1; }
        if [[ "$(command -v vscodex-app-server || true)" != "$target" ]]; then
            echo 'Add the installation directory to the VS Code extension host PATH.' >&2
            exit 1
        fi
        echo 'Managed command is executable and discoverable on this PATH.'
        exit 0
        ;;
    install) ;;
    *) echo 'Expected install, check, or uninstall.' >&2; exit 2 ;;
esac

mkdir -p -- "$directory"
exists=false
if [[ -e "$target" || -L "$target" ]]; then
    managed || { echo 'Refusing to replace an unmanaged command.' >&2; exit 1; }
    exists=true
fi
draft=$(mktemp -- "$directory/.vscodex-install.XXXXXXXX")
trap 'rm -f -- "$draft"' EXIT
cat > "$draft" <<'PYTHON'
#!/usr/bin/env python3
# Managed by vscode-codex-account (Linux).
import json
import os
from pathlib import Path
import platform
import re
import sys


def bundled_binary():
    # The Codex extension appends its own platform bin directory for each spawn.
    last = os.environ.get("PATH", "").rstrip(":").split(":")[-1]
    directory = Path(last)
    arch = {"x86_64": ("x64", "linux-x86_64"), "aarch64": ("arm64", "linux-aarch64")}.get(platform.machine())
    extension = directory.parent.parent
    if not arch or not directory.is_absolute() or directory.name != arch[1] or directory.parent.name != "bin":
        raise ValueError("Expected the Linux Codex extension bin directory at the end of PATH.")
    match = re.fullmatch(r"openai\.chatgpt-(\d+\.\d+\.\d+(?:-[a-z0-9.]+)*)-linux-" + arch[0],
                         extension.name, re.IGNORECASE)
    manifest = json.loads((extension / "package.json").read_bytes()) if match else {}
    if (not match or not isinstance(manifest, dict)
            or manifest.get("name") != "chatgpt" or str(manifest.get("publisher", "")).lower() != "openai"
            or manifest.get("version") != match[1]):
        raise ValueError("Expected the installed OpenAI Codex extension for this architecture.")
    binary = directory / "codex"
    if not binary.is_file() or not os.access(binary, os.X_OK) or binary.resolve().parent != directory.resolve():
        raise ValueError("The extension's bundled executable is unavailable.")
    return str(binary)


def launch(extra_bypass):
    binary = bundled_binary()
    # Respect the extension's effective HTTP(S) proxy, including for websocket clients.
    secure = os.getenv("HTTPS_PROXY") or os.getenv("https_proxy")
    plain = os.getenv("HTTP_PROXY") or os.getenv("http_proxy")
    if secure or plain:
        for scheme, value in (("HTTP", plain or secure), ("HTTPS", secure or plain),
                              ("WS", plain or secure), ("WSS", secure or plain)):
            os.environ[scheme + "_PROXY"] = os.environ[scheme.lower() + "_proxy"] = value
        fallback = os.getenv("ALL_PROXY") or os.getenv("all_proxy") or secure or plain
        os.environ["ALL_PROXY"] = os.environ["all_proxy"] = fallback
        bypass = ",".join(filter(None, [os.getenv("NO_PROXY"), os.getenv("no_proxy"),
                                        "localhost,127.0.0.1,::1", extra_bypass]))
        os.environ["NO_PROXY"] = os.environ["no_proxy"] = ",".join(dict.fromkeys(bypass.split(",")))
    os.execv(binary, [binary, *sys.argv[1:]])


PYTHON
# Optional machine-specific exclusions stay in the installed command only. Preserve
# them on upgrades unless explicitly replaced. A JSON string is also a Python literal.
python3 - "$target" "$draft" <<'PYTHON'
import json
import os
from pathlib import Path
import sys

target, draft = map(Path, sys.argv[1:])
prefix = "extra_bypass = "
value = os.getenv("VSCODEX_LINUX_NO_PROXY")
if value is None:
    value = ""
    if target.exists():
        for line in target.read_text(encoding="utf-8").splitlines():
            if line.startswith(prefix):
                value = json.loads(line[len(prefix):])
                break
with draft.open("a", encoding="utf-8") as output:
    output.write(prefix + json.dumps(value, ensure_ascii=False) + "\n")
PYTHON
cat >> "$draft" <<'PYTHON'
try:
    launch(extra_bypass)
except (OSError, ValueError, TypeError) as error:
    print("vscodex-app-server:", error, file=sys.stderr)
    sys.exit(1)
PYTHON
chmod 700 "$draft"
if "$exists"; then
    managed || { echo 'Installation target changed.' >&2; exit 1; }
    mv -fT -- "$draft" "$target"
else
    # Publish only if another command hasn't appeared since the capability check.
    ln -- "$draft" "$target"
fi
echo 'Installed vscodex-app-server. Use check from the target host PATH to verify.'
