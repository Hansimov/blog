"""Manage local Windows VS Code Codex accounts. Requires Python 3.9+."""
import argparse
import base64
from contextlib import contextmanager
import ctypes
from ctypes import wintypes
import hashlib
import json
import msvcrt
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import tempfile
import time
import winreg


ROOT = Path(os.environ["LOCALAPPDATA"]) / "vscode-codex-account"
ACCOUNTS = ROOT / "accounts"
SELECTED = ROOT / "selected"
SETTINGS = Path(os.environ["APPDATA"]) / "Code" / "User" / "settings.json"
EXECUTABLE = "chatgpt.cliExecutable"
IGNORED = "settingsSync.ignoredSettings"
STRING = r'"(?:\\.|[^"\\])*"'
LAUNCHER = re.compile(r"extension-launcher(?:-[a-fA-F0-9]+)?\.exe", re.I)
BLUE = "94"
SKY_BLUE = "38;2;135;206;235"
GREEN = "92"
RED = "91"


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as temp:
        name = Path(temp.name)
    try:
        name.write_bytes(data)
        os.replace(name, path)
    finally:
        name.unlink(missing_ok=True)


def read_settings():
    data = SETTINGS.read_bytes() if SETTINGS.exists() else b"{}\n"
    source = data.decode("utf-8-sig")
    # Keep offsets, strings, comments and trailing commas intact in the source.
    def mask(match):
        value = match[0]
        return value if value.startswith('"') else re.sub(r"[^\r\n]", " ", value)

    clean = re.sub(STRING + r"|//[^\r\n]*|/\*[\s\S]*?\*/", mask, source)
    clean = re.sub(STRING + r"|,(?=\s*[}\]])", mask, clean)
    values = json.loads(clean)
    if not isinstance(values, dict):
        raise ValueError("VS Code user settings must contain a JSON object.")
    decoder = json.JSONDecoder()
    spans = {}
    cursor = clean.index("{") + 1
    while True:
        cursor = re.compile(r"[\s,]*").match(clean, cursor).end()
        if clean[cursor] == "}":
            break
        key, end = decoder.raw_decode(clean, cursor)
        start = re.compile(r"\s*:\s*").match(clean, end).end()
        _, cursor = decoder.raw_decode(clean, start)
        if key in spans and key in (EXECUTABLE, IGNORED):
            raise ValueError(f"Resolve duplicate {key} in VS Code user settings first.")
        spans[key] = (start, cursor)
    return data, source, clean.index("{") + 1, values, spans


def our_launcher(path):
    return path.parent == ROOT and LAUNCHER.fullmatch(path.name)


def configure(launcher):
    path = Path(launcher).resolve()
    if not our_launcher(path) or not path.is_file():
        raise ValueError("Expected the installed extension launcher.")
    shared = ROOT / "shared-home"
    if not shared.is_file():
        # An installer run inside an old Codex window inherits its private slot.
        original = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex").resolve()
        if original.is_relative_to(ROOT):
            original = Path.home() / ".codex"
            for hive, subkey in ((winreg.HKEY_CURRENT_USER, "Environment"),
                                 (winreg.HKEY_LOCAL_MACHINE,
                                  r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment")):
                try:
                    with winreg.OpenKey(hive, subkey) as key:
                        value = winreg.QueryValueEx(key, "CODEX_HOME")[0]
                except FileNotFoundError:
                    continue
                if value:
                    original = Path(os.path.expandvars(value)).resolve()
                    break
        if original.resolve().is_relative_to(ROOT):
            raise ValueError("Set CODEX_HOME to the original Codex directory before installing.")
        original.mkdir(parents=True, exist_ok=True)
        atomic_write(shared, str(original).encode("utf-8"))
    data, source, opening, values, spans = read_settings()
    old = values.get(EXECUTABLE)
    if old and (not isinstance(old, str) or not our_launcher(Path(old))):
        raise ValueError(f"A custom {EXECUTABLE} already exists. Review it before installing.")
    edits = []
    new_keys = {}
    if old != str(path):
        if EXECUTABLE in spans:
            edits.append((*spans[EXECUTABLE], json.dumps(str(path))))
        else:
            new_keys[EXECUTABLE] = str(path)
    ignored = values.get(IGNORED, [])
    if not isinstance(ignored, list) or "-" + EXECUTABLE in ignored:
        raise ValueError(f"Review {IGNORED} before installing a machine-local launcher.")
    if EXECUTABLE not in ignored:
        if IGNORED in spans:
            start = spans[IGNORED][0] + 1
            edits.append((start, start, json.dumps(EXECUTABLE) + (", " if ignored else "")))
        else:
            new_keys[IGNORED] = [EXECUTABLE]
    if new_keys:
        newline = "\r\n" if "\r\n" in source else "\n"
        entries = ("," + newline + "    ").join(
            json.dumps(k) + ": " + json.dumps(v) for k, v in new_keys.items())
        edits.append((opening, opening, newline + "    " + entries + ("," if values else newline)))
    subprocess.run([sys.executable, "-I", str(ROOT / "backend.py"), str(path), "--import-history"], check=True)
    if edits:
        for start, end, replacement in sorted(edits, reverse=True):
            source = source[:start] + replacement + source[end:]
        if SETTINGS.exists() and SETTINGS.read_bytes() != data:
            raise ValueError("VS Code settings changed during installation. Rerun the installer.")
        encoding = "utf-8-sig" if data.startswith(b"\xef\xbb\xbf") else "utf-8"
        atomic_write(SETTINGS, source.encode(encoding))


def binding(home):
    return (home / "email").read_text(encoding="utf-8").strip()


def identity(auth):
    """Read only the local login identity. Never include raw JSON in errors."""
    try:
        cache = json.loads(auth.read_bytes())
        tokens = cache["tokens"]
        if cache.get("auth_mode") not in (None, "chatgpt") or not all(
                tokens.get(k) for k in ("id_token", "access_token", "refresh_token")):
            raise ValueError()
        claim = tokens["id_token"].split(".")[1]
        email = json.loads(base64.urlsafe_b64decode(claim + "=" * (-len(claim) % 4)))["email"]
        if not isinstance(email, str) or not email.strip():
            raise ValueError()
        return email.strip()
    except (KeyError, ValueError, TypeError, IndexError, AttributeError):
        raise ValueError("Invalid cached ChatGPT credentials. Run login with --again.") from None


def check_login(home):
    expected = binding(home)
    auth = home / "auth.json"
    if not auth.is_file():
        raise ValueError(f"Device authorization needed. Run: vscodex login {expected}")
    if identity(auth).casefold() != expected.casefold():
        raise ValueError("Cached account differs from the registered email. Run login with --again.")


@contextmanager
def account_lock(home):
    home.mkdir(parents=True, exist_ok=True)
    with (home / ".vscodex.lock").open("a+b") as lock:
        lock.seek(0)
        try:
            msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            raise ValueError("A login for this account is already in progress.") from None
        try:
            yield
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


@contextmanager
def console_colors():
    # The native device prompt also uses ANSI. Enable it on console handles only.
    kernel = ctypes.windll.kernel32
    ansi_flags = 0x0001 | 0x0004  # ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING
    changed = []
    terminals = set()

    def paint(text, foreground, fd=1):
        if fd in terminals:
            return f"\x1b[{foreground}m{text}\x1b[39m"
        return text

    try:
        for fd in (1, 2):
            try:
                handle = wintypes.HANDLE(msvcrt.get_osfhandle(fd))
            except OSError:
                continue
            mode = wintypes.DWORD()
            if kernel.GetConsoleMode(handle, ctypes.byref(mode)):
                enabled = mode.value | ansi_flags
                if enabled != mode.value:
                    if not kernel.SetConsoleMode(handle, enabled):
                        continue
                    changed.append((handle, mode.value))
                terminals.add(fd)
        yield paint
    finally:
        for handle, previous in reversed(changed):
            kernel.SetConsoleMode(handle, previous)


def login(selector, again, paint):
    home, expected = resolve_account(selector, enroll=True)
    with account_lock(home):
        marker = home / "email"
        if not marker.exists():
            atomic_write(marker, expected.encode("utf-8"))
        elif binding(home).casefold() != expected.casefold():
            raise ValueError("This storage directory already belongs to a different email.")
        if (home / "auth.json").exists() and not again:
            check_login(home)
            print(paint(f"{expected} already has cached credentials.", GREEN))
            return
        settings = read_settings()[3]
        launcher = Path(settings.get(EXECUTABLE) or "")
        if not our_launcher(launcher) or not launcher.is_file():
            raise ValueError("Run install.ps1 to configure the local extension launcher.")
        binary = subprocess.check_output([str(launcher), "--vscodex-bundled-path"],
                                         encoding="utf-8").strip()
        # A cancelled or wrong-account login must leave the previous token intact.
        with tempfile.TemporaryDirectory(dir=ROOT, prefix="enroll-") as scratch:
            env = dict(os.environ, CODEX_HOME=scratch)
            # Match the extension's network environment even in a standalone cmd.
            proxy = settings.get("http.proxy")
            if isinstance(proxy, str) and proxy.strip():
                env.update(HTTP_PROXY=proxy.strip(), HTTPS_PROXY=proxy.strip())
            print(f"Authorize {expected} in the browser.", flush=True)
            result = subprocess.run([binary, "-c", 'cli_auth_credentials_store="file"',
                                     "login", "--device-auth"], env=env)
            if result.returncode:
                raise ValueError("Device authorization did not complete. Rerun login to retry.")
            auth = Path(scratch) / "auth.json"
            if identity(auth).casefold() != expected.casefold():
                raise ValueError("The browser authorized a different email. Rerun login with the registered account.")
            os.replace(auth, home / "auth.json")
    print(paint(f"Saved {expected}. Select it with: vscodex use {expected}", GREEN))


def accounts_by_email():
    # Existing directories stay in place: running backends refresh tokens there.
    accounts = {}
    if ACCOUNTS.is_dir():
        for home in sorted(ACCOUNTS.iterdir()):
            if home.is_dir() and (home / "email").is_file():
                accounts.setdefault(binding(home).casefold(), []).append(home)
    return accounts


def selected_slot():
    try:
        return SELECTED.read_text(encoding="ascii").strip()
    except FileNotFoundError:
        return None


def preferred_home(homes):
    if len(homes) == 1:
        return homes[0]
    # Older installations could register one email several times. Reuse a valid
    # credential and prefer the selected directory when multiple are available.
    current = selected_slot()

    def priority(home):
        try:
            check_login(home)
            cached = True
        except (ValueError, OSError):
            cached = False
        return cached, home.name == current

    return max(homes, key=priority)


def resolve_account(selector, *, enroll=False):
    email = selector.strip()
    query = email.casefold()
    accounts = accounts_by_email()
    if query in accounts:
        home = preferred_home(accounts[query])
        return home, binding(home)
    if re.fullmatch(r"[^\s@<>]+@[\w-]+(?:\.[\w-]+)+", email):
        if not enroll:
            raise ValueError(f"This email has no login. Run: vscodex login {email}")
        # A stable, filename-safe ID fits the launcher's 32-character limit.
        key = "acct-" + hashlib.sha256(query.encode("utf-8")).hexdigest()[:27]
        return ACCOUNTS / key, email
    fragment = query.removesuffix("...").removesuffix("…")
    if not fragment:
        raise ValueError("Enter a full email or a unique part of a known email.")
    matches = [key for key in accounts if fragment in key]
    if not matches:
        raise ValueError("No matching account. For a new account, run vscodex login with its full email.")
    if len(matches) > 1:
        raise ValueError("Several emails match. Enter a longer fragment or a full email: "
                         + ", ".join(sorted(matches)))
    home = preferred_home(accounts[matches[0]])
    return home, binding(home)


def select(selector, paint):
    if selector.strip().casefold() == "original":
        SELECTED.unlink(missing_ok=True)
        label = "original"
    else:
        home, email = resolve_account(selector)
        check_login(home)
        atomic_write(SELECTED, home.name.encode("ascii"))
        label = email
    print(paint("Selected for next window load:", GREEN), paint(label, BLUE))
    print("In each VS Code window to switch, run " + paint("Developer: Reload Window", SKY_BLUE) + ".")


def in_use(slot):
    # The launcher keeps this event alive while any window runs this account.
    kernel = ctypes.windll.kernel32
    open_event = kernel.OpenEventW
    open_event.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.LPCWSTR]
    open_event.restype = wintypes.HANDLE
    handle = open_event(0x00100000, False, f"Local\\vscodex.active.{slot}")  # SYNCHRONIZE
    if not handle:
        return False
    kernel.CloseHandle(wintypes.HANDLE(handle))
    return True


def status(paint):
    accounts = accounts_by_email()
    current = selected_slot()
    emails_by_slot = {home.name: email for email, homes in accounts.items() for home in homes}
    selected = emails_by_slot.get(current, "unavailable") if current else "original"
    print("Selected for next window load:", paint(selected, RED if selected == "unavailable" else BLUE))
    if in_use("original") or in_use("shared.original"):
        print(f"  {paint('original', BLUE)}  {paint('[in use]', GREEN)}")
    for email, homes in sorted(accounts.items()):
        home = preferred_home(homes)
        try:
            check_login(home)
            state = paint("[cached]", SKY_BLUE)
        except ValueError as exc:
            state = paint(f"[{exc}]", RED)
        if any(in_use(slot.name) or in_use("shared." + slot.name) for slot in homes):
            state += "  " + paint("[in use]", GREEN)
        print(f"  {paint(email, BLUE)}  {state}")


def release_thread(selector, paint):
    # The installed shim starts Python with -I. Use only our installed siblings.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from backend import local_request
    from release_channel import request_release
    from thread_lookup import canonical_id, resolve_thread, writer_pids

    shared = Path((ROOT / "shared-home").read_text(encoding="utf-8").strip())
    thread_id = canonical_id(selector.strip())
    if not thread_id:
        launcher = Path(read_settings()[3].get(EXECUTABLE) or "")
        if not our_launcher(launcher) or not launcher.is_file():
            raise ValueError("Run install.ps1 to configure the local extension launcher.")
        exe = subprocess.check_output([str(launcher), "--vscodex-bundled-path"],
                                      encoding="utf-8", timeout=10).strip()
        config = local_request(exe, shared, "config/read", {}, timeout=10)["config"]
        thread_id = resolve_thread(shared, selector, config.get("sqlite_home"))
    owners = writer_pids(shared, thread_id)
    if not owners:
        print(paint("This thread has no active writer. You can open it in the destination window.", GREEN))
        return
    if len(owners) != 1:
        raise ValueError("Cannot identify a single writer. No release was requested.")
    owner = owners.pop()
    outcome = request_release(ROOT, owner, thread_id)
    if outcome == "unmanaged":
        raise ValueError("This writer has no vscodex release channel. If it is an older VS Code window, "
                         "wait for its tasks to finish, then reload it once. A separate app must release its own thread.")
    if outcome == "busy":
        raise ValueError("The thread is active or has an outstanding request. Let it finish, then retry.")
    if outcome == "timeout":
        raise ValueError("The owning window did not confirm in time. Check the destination window before retrying.")
    if outcome not in ("released", "not_loaded"):
        raise ValueError("The owning backend could not confirm the handoff. Its window is still open.")

    # A native unsubscribe acknowledgement precedes the actual release by up to
    # a minute with the default server settings. Check the OS before reporting success.
    deadline = time.monotonic() + 75
    print("Waiting for Codex to release the writer (usually up to one minute)...", flush=True)
    while owner in writer_pids(shared, thread_id):
        if time.monotonic() >= deadline:
            raise ValueError("The owner still holds this thread. Switch away from the thread there and retry.")
        time.sleep(1)
    print(paint("The previous writer released this thread.", GREEN),
          "Click " + paint("Retry", SKY_BLUE) + " in the destination window.")


def main(paint):
    parser = argparse.ArgumentParser(prog="vscodex", description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    enroll = commands.add_parser("login", help="authorize a new email or reuse an existing login")
    enroll.add_argument("account", help="full email for first login, or unique part of a known email")
    enroll.add_argument("--again", action="store_true", help="replace a revoked or invalid login")
    use = commands.add_parser("use", help="select an authorized account by email or unique fragment")
    use.add_argument("account", help="full email, unique part of an email, or original")
    release = commands.add_parser("release", help="release one idle thread for use in another window")
    release.add_argument("thread", help="exact thread title or full thread UUID")
    commands.add_parser("status", help="show selection and locally cached identities")
    setup = commands.add_parser("configure", help="configure the installed extension launcher")
    setup.add_argument("launcher")
    args = parser.parse_args()
    if not (ROOT / "run.ps1").is_file():
        raise ValueError("Run install.ps1 before using vscodex.")
    if args.action == "login":
        login(args.account, args.again, paint)
    elif args.action == "use":
        select(args.account, paint)
    elif args.action == "release":
        release_thread(args.thread, paint)
    elif args.action == "configure":
        configure(args.launcher)
    else:
        status(paint)


if __name__ == "__main__":
    with console_colors() as color:
        try:
            main(color)
        except (OSError, ValueError, sqlite3.Error, subprocess.SubprocessError) as error:
            print(color(f"vscodex: {error}", RED, fd=2), file=sys.stderr, flush=True)
            sys.exit(1)
        except KeyboardInterrupt:
            print(color("Command cancelled.", RED, fd=2), file=sys.stderr, flush=True)
            sys.exit(1)
