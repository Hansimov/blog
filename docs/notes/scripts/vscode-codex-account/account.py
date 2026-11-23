"""Manage local Windows VS Code Codex accounts. Requires Python 3.9+."""
import argparse
import base64
from contextlib import contextmanager
import ctypes
from ctypes import wintypes
import json
import msvcrt
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(os.environ["LOCALAPPDATA"]) / "vscode-codex-account"
ACCOUNTS = ROOT / "accounts"
SELECTED = ROOT / "selected"
SETTINGS = Path(os.environ["APPDATA"]) / "Code" / "User" / "settings.json"
EXECUTABLE = "chatgpt.cliExecutable"
IGNORED = "settingsSync.ignoredSettings"
RELOAD = "In each VS Code window to switch, run Developer: Reload Window."
STRING = r'"(?:\\.|[^"\\])*"'
LAUNCHER = re.compile(r"extension-launcher(?:-[a-fA-F0-9]+)?\.exe", re.I)


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
    if edits:
        for start, end, replacement in sorted(edits, reverse=True):
            source = source[:start] + replacement + source[end:]
        if SETTINGS.exists() and SETTINGS.read_bytes() != data:
            raise ValueError("VS Code settings changed during installation. Rerun the installer.")
        encoding = "utf-8-sig" if data.startswith(b"\xef\xbb\xbf") else "utf-8"
        atomic_write(SETTINGS, source.encode(encoding))


def alias(value):
    if (not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", value)
            or re.fullmatch(r"original|con|aux|prn|nul|com[0-9]|lpt[0-9]", value)):
        raise argparse.ArgumentTypeError("Choose a short lowercase account alias, e.g. primary.")
    return value


def binding(home):
    try:
        return (home / "email").read_text(encoding="utf-8").strip()
    except FileNotFoundError:
        raise ValueError(f"Register this account first: vscodex add {home.name} EMAIL") from None


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
        raise ValueError(f"Device authorization needed. Run: vscodex login {home.name}")
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
            raise ValueError("Another command is registering or logging into this account.") from None
        try:
            yield
        finally:
            lock.seek(0)
            msvcrt.locking(lock.fileno(), msvcrt.LK_UNLCK, 1)


def register(home, email):
    if not re.fullmatch(r"[^\s@]+@[^\s@]+", email):
        raise ValueError("Enter the ChatGPT account email.")
    with account_lock(home):
        if (home / "email").exists() and binding(home).casefold() != email.casefold():
            raise ValueError("This alias already belongs to another email. Choose a different alias.")
        atomic_write(home / "email", email.encode("utf-8"))
    print(f"Registered {home.name}.")


@contextmanager
def device_login_console():
    # Codex prints ANSI colors in its device prompt. Classic Windows consoles can
    # start with VT processing disabled even when stdout and stderr are terminals.
    kernel = ctypes.windll.kernel32
    ansi_flags = 0x0001 | 0x0004  # ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING
    changed = []
    try:
        for fd in (1, 2):
            try:
                handle = wintypes.HANDLE(msvcrt.get_osfhandle(fd))
            except OSError:
                continue
            mode = wintypes.DWORD()
            if kernel.GetConsoleMode(handle, ctypes.byref(mode)):
                enabled = mode.value | ansi_flags
                if enabled != mode.value and kernel.SetConsoleMode(handle, enabled):
                    changed.append((handle, mode.value))
        yield
    finally:
        for handle, previous in reversed(changed):
            kernel.SetConsoleMode(handle, previous)


def login(home, again):
    with account_lock(home):
        expected = binding(home)
        if (home / "auth.json").exists() and not again:
            check_login(home)
            print(f"{home.name} already has cached credentials.")
            return
        launcher = Path(read_settings()[3].get(EXECUTABLE) or "")
        if not our_launcher(launcher) or not launcher.is_file():
            raise ValueError("Run install.ps1 to configure the local extension launcher.")
        binary = subprocess.check_output([str(launcher), "--vscodex-bundled-path"],
                                         encoding="utf-8").strip()
        # A cancelled or wrong-account login must leave the previous token intact.
        with tempfile.TemporaryDirectory(dir=ROOT, prefix="enroll-") as scratch:
            env = dict(os.environ, CODEX_HOME=scratch)
            print(f"Authorize {home.name} as {expected} in the browser.", flush=True)
            with device_login_console():
                result = subprocess.run([binary, "-c", 'cli_auth_credentials_store="file"',
                                         "login", "--device-auth"], env=env)
            if result.returncode:
                raise ValueError("Device authorization did not complete. Rerun login to retry.")
            auth = Path(scratch) / "auth.json"
            if identity(auth).casefold() != expected.casefold():
                raise ValueError("The browser authorized a different email. Rerun login with the registered account.")
            # Seed existing user preferences once. OAuth state and history stay independent.
            original = Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")
            for filename in ("config.toml", "AGENTS.md"):
                source, target = original / filename, home / filename
                if source.is_file() and not target.exists():
                    shutil.copyfile(source, target)
            os.replace(auth, home / "auth.json")
    print(f"Saved {home.name}. Select it with: vscodex use {home.name}")


def registered_accounts():
    if ACCOUNTS.is_dir():
        for home in sorted(ACCOUNTS.iterdir()):
            if home.is_dir() and (home / "email").is_file():
                yield home, binding(home)


def resolve_account(selector):
    query = selector.strip().casefold()
    accounts = list(registered_accounts())
    matches = [(home, email) for home, email in accounts
               if query in (home.name.casefold(), email.casefold())]
    if not matches:
        prefix = query.removesuffix("...").removesuffix("…")
        if not prefix:
            raise ValueError("Enter an account alias, email or unique prefix.")
        matches = [(home, email) for home, email in accounts
                   if home.name.casefold().startswith(prefix) or email.casefold().startswith(prefix)]
    if not matches:
        raise ValueError("No matching account. Run vscodex status to see registered accounts.")
    if len(matches) > 1:
        choices = ", ".join(f"{home.name} ({email})" for home, email in matches)
        raise ValueError(f"Ambiguous account prefix. Choose a listed alias or a unique email: {choices}")
    return matches[0]


def select(selector):
    if selector.strip().casefold() == "original":
        SELECTED.unlink(missing_ok=True)
        label = "original"
    else:
        home, email = resolve_account(selector)
        check_login(home)
        atomic_write(SELECTED, home.name.encode("ascii"))
        label = f"{email} ({home.name})"
    print(f"Selected {label} for the next VS Code Codex backend startup. {RELOAD}")


def status():
    current = SELECTED.read_text(encoding="ascii").strip() if SELECTED.exists() else "original"
    print(f"Selected for next window load: {current}")
    for home, email in registered_accounts():
        try:
            check_login(home)
            state = "cached"
        except ValueError as exc:
            state = str(exc)
        print(f"  {home.name:<12} {email}  [{state}]")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    add = commands.add_parser("add", help="register an alias and its expected ChatGPT email")
    add.add_argument("alias", type=alias)
    add.add_argument("email")
    enroll = commands.add_parser("login", help="authorize an account with a device code")
    enroll.add_argument("alias", type=alias)
    enroll.add_argument("--again", action="store_true", help="replace a revoked or invalid login")
    use = commands.add_parser("use", help="select an enrolled account by alias, email or unique prefix")
    use.add_argument("account", help="alias, full email, unique prefix, or original")
    commands.add_parser("status", help="show selection and locally cached identities")
    setup = commands.add_parser("configure", help="configure the installed extension launcher")
    setup.add_argument("launcher")
    args = parser.parse_args()
    if not (ROOT / "run.ps1").is_file():
        raise ValueError("Run install.ps1 before using vscodex.")
    if args.action == "add":
        register(ACCOUNTS / args.alias, args.email)
    elif args.action == "login":
        login(ACCOUNTS / args.alias, args.again)
    elif args.action == "use":
        select(args.account)
    elif args.action == "configure":
        configure(args.launcher)
    else:
        status()


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        sys.exit(f"vscodex: {error}")
    except KeyboardInterrupt:
        sys.exit("Login cancelled.")
