"""Start the bundled stdio app-server in the shared home with a window-local login."""
import base64
from contextlib import contextmanager
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import sys
import threading
import time
import uuid

# The installer invokes Python in isolated mode. Only load our installed siblings.
sys.path.insert(0, str(Path(__file__).resolve().parent))
import account
import history
from release_channel import serve_releases
from thread_control import ThreadControl


def encode(message):
    return json.dumps(message, separators=(",", ":")).encode() + b"\n"


def send(stream, message):
    stream.write(encode(message))
    stream.flush()


@contextmanager
def server(exe, args, home):
    # Read large history replies in larger chunks. Individual RPC writes still flush immediately.
    proc = subprocess.Popen([exe, *args], env=dict(os.environ, CODEX_HOME=str(home)),
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=64 * 1024)
    try:
        yield proc
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait()
        proc.stdout.close()
        proc.stdin.close()


def response(proc, request, forward=None):
    send(proc.stdin, request)
    for line in proc.stdout:
        message = json.loads(line)
        if "method" not in message and message.get("id") == request["id"]:
            return message
        if forward:
            forward(line)
    raise ValueError("Codex exited during " + request["method"])


def local_request(exe, home, method, params, timeout=None):
    with server(exe, ["-c", 'cli_auth_credentials_store="file"', "app-server"], home) as proc:
        timer = threading.Timer(timeout, proc.kill) if timeout is not None else None
        if timer:
            timer.start()
        try:
            initialize = {"clientInfo": {"name": "vscodex", "version": "1"}}
            for i, (name, arguments) in enumerate([("initialize", initialize), (method, params)]):
                reply = response(proc, {"id": i, "method": name, "params": arguments})
                if "error" in reply:
                    raise ValueError("Bundled Codex could not complete " + name)
            return reply["result"]
        finally:
            if timer:
                timer.cancel()


def claims(jwt):
    payload = jwt.split(".")[1]
    return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))


def login_tokens(exe, slot, previous=None):
    # Only the file-backed native auth manager ever handles token rotation. The
    # shared server receives a short-lived access token over its private pipe.
    path = slot / "auth.json"
    def read():
        try:
            tokens = json.loads(path.read_bytes())["tokens"]
            identity = claims(tokens["id_token"])
            if identity["email"].casefold() != account.binding(slot).casefold():
                raise ValueError()
            scope = identity.get("https://api.openai.com/auth", {})
            workspace = tokens.get("account_id") or scope["chatgpt_account_id"]
            expires = int(claims(tokens["access_token"])["exp"])
            return dict(accessToken=tokens["access_token"], chatgptAccountId=workspace,
                        chatgptPlanType=scope.get("chatgpt_plan_type")), expires
        except (KeyError, TypeError, IndexError, AttributeError, OSError, ValueError):
            raise ValueError("Invalid account credentials. Run vscodex login with --again.") from None

    tokens, expires = read()
    if expires <= time.time() + 30 or previous == tokens["accessToken"]:
        local_request(exe, slot, "getAuthStatus", {"includeToken": False, "refreshToken": True})
        tokens, expires = read()
        if expires <= time.time() or previous == tokens["accessToken"]:
            raise ValueError("Codex could not renew this login. Run vscodex login with --again.")
    return tokens


def forward(line):
    sys.stdout.buffer.write(line)
    sys.stdout.buffer.flush()


def serve(exe, args, shared, slot):
    if slot is not None:
        args = [*args, "-c", 'cli_auth_credentials_store="ephemeral"']
    with server(exe, args, shared) as proc:
        # Complete login before releasing initialize, so the extension's first
        # account/read and thread/list already see the selected identity.
        first = sys.stdin.buffer.readline()
        if not first:
            return 0
        initialize = json.loads(first)
        if initialize.get("method") != "initialize":
            raise ValueError("Expected the VS Code stdio initialize handshake.")
        if slot is not None:
            capabilities = initialize["params"].get("capabilities") or {}
            initialize["params"]["capabilities"] = dict(capabilities, experimentalApi=True)
        initialized = response(proc, initialize, forward)
        if "error" in initialized:
            forward(encode(initialized))
            return 1
        if slot is not None:
            tokens = login_tokens(exe, slot)
            login = {"id": str(uuid.uuid4()), "method": "account/login/start",
                     "params": dict(type="chatgptAuthTokens", **tokens)}
            result = response(proc, login, forward)
            if "error" in result:
                raise ValueError("The bundled Codex app-server rejected the selected account login.")
        forward(encode(initialized))

        control = ThreadControl(proc.stdin)
        output_lock = threading.Lock()
        def client_input():
            try:
                for line in sys.stdin.buffer:
                    if slot is not None and b'"account/logout"' in line:
                        request = json.loads(line)
                        if request.get("method") == "account/logout":
                            try:
                                local_request(exe, slot, "account/logout", None)
                            except (OSError, ValueError, subprocess.SubprocessError):
                                with output_lock:
                                    forward(encode({"id": request["id"], "error": {"code": -32000,
                                                    "message": "Could not sign out the selected account."}}))
                                continue
                    error = control.from_editor(line)
                    if error:
                        with output_lock:
                            forward(encode(error))
            except (BrokenPipeError, ValueError):
                pass
            finally:
                control.close_input()

        with serve_releases(account.ROOT, proc.pid, control.release):
            threading.Thread(target=client_input, daemon=True).start()
            for line in proc.stdout:
                if control.from_native(line):
                    continue
                if slot is not None and b'"account/chatgptAuthTokens/refresh"' in line:
                    message = json.loads(line)
                    if message.get("method") == "account/chatgptAuthTokens/refresh" and "id" in message:
                        try:
                            fresh = login_tokens(exe, slot, tokens["accessToken"])
                            workspace = message.get("params", {}).get("previousAccountId")
                            if workspace and fresh["chatgptAccountId"] != workspace:
                                raise ValueError("Selected workspace changed. Reload the window.")
                            tokens = fresh
                            reply = {"id": message["id"], "result": tokens}
                        except (OSError, ValueError, subprocess.SubprocessError):
                            reply = {"id": message["id"], "error": {"code": -32000,
                                     "message": "Refresh failed. Run vscodex login with --again."}}
                        if not proc.stdin.closed:
                            control.write(encode(reply))
                        continue
                with output_lock:
                    forward(line)
        return proc.wait()


def run_history_import(shared, config):
    try:
        conflicts = history.import_accounts(shared, config)
    except (OSError, ValueError, sqlite3.Error, subprocess.SubprocessError) as error:
        # stdout is the extension's JSON-RPC pipe. Avoid private paths and thread IDs in logs.
        print(f"vscodex: legacy history import deferred ({type(error).__name__}).",
              file=sys.stderr, flush=True)
        return
    if conflicts:
        print(f"vscodex: kept both versions of {conflicts} conflicting legacy history file(s).",
              file=sys.stderr, flush=True)


def main():
    exe, slot, *args = sys.argv[1:]
    shared = Path((account.ROOT / "shared-home").read_text(encoding="utf-8"))
    def config(home):
        nonlocal exe
        if slot == "--import-history" and account.our_launcher(Path(exe)):
            exe = subprocess.check_output([exe, "--vscodex-bundled-path"], encoding="utf-8").strip()
        return local_request(exe, home, "config/read", {})["config"]

    if slot == "--import-history":
        run_history_import(shared, config)
        return 0
    # History import may wait on a live writer or another window's migration.
    # Start serving the extension immediately, including in the original home.
    threading.Thread(target=run_history_import, args=(shared, config), daemon=True).start()
    return serve(exe, args, shared, None if slot == "original" else account.ACCOUNTS / slot)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        print("vscodex backend:", exc, file=sys.stderr)
        sys.exit(1)
