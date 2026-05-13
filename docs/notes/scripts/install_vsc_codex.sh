#!/usr/bin/env bash
set -euo pipefail

EXT="${1:-openai.chatgpt}"
VSCODE_ROOT="${VSCODE_AGENT_FOLDER:-$HOME/.vscode-server}"

echo "[info] user: $(id -un)"
echo "[info] home: $HOME"
echo "[info] vscode root: $VSCODE_ROOT"
echo "[info] extension: $EXT"

if [[ ! -d "$VSCODE_ROOT" ]]; then
  echo "[error] VS Code Server root not found: $VSCODE_ROOT" >&2
  echo "[error] Open this host once with VS Code Remote SSH first." >&2
  exit 1
fi

echo "[1/4] Find Microsoft VS Code Server code-server binary..."

CODE_SERVER="$(
  find "$VSCODE_ROOT" \
    -type f \
    \( -path '*/server/bin/code-server' -o -path '*/bin/code-server' \) \
    2>/dev/null \
    | sort \
    | tail -n 1
)"

if [[ -z "${CODE_SERVER}" ]]; then
  echo "[error] Cannot find code-server under: $VSCODE_ROOT" >&2
  echo "[debug] Existing files:" >&2
  find "$VSCODE_ROOT" -maxdepth 6 -type f -name 'code*' 2>/dev/null | sort | tail -n 50 >&2
  exit 1
fi

echo "[info] code-server: $CODE_SERVER"

EXT_DIR="$VSCODE_ROOT/extensions"
mkdir -p "$EXT_DIR"

echo "[2/4] Install extension into remote VS Code Server..."
"$CODE_SERVER" \
  --install-extension "$EXT" \
  --extensions-dir "$EXT_DIR" \
  --force

echo "[3/4] Verify extension list..."
"$CODE_SERVER" \
  --list-extensions \
  --show-versions \
  --extensions-dir "$EXT_DIR" \
  | grep -i '^openai\.chatgpt' || {
    echo "[warn] openai.chatgpt not found in code-server extension list"
  }

echo "[4/4] Extension directory:"
find "$EXT_DIR" -maxdepth 1 -type d -iname 'openai.chatgpt*' -print -exec du -sh {} \; 2>/dev/null || true

echo "[done]"