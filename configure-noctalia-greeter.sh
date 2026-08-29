#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "error: run as root (use sudo)." >&2
    exit 1
fi

if [[ $# -ne 2 || ! -x "$1" ]]; then
    echo "Usage: sudo $0 /path/to/setup_greeter_system.sh LOGIN_USER" >&2
    exit 2
fi

readonly OFFICIAL_SETUP="$1"
readonly LOGIN_USER="$2"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TRACKED_CONFIG="$SCRIPT_DIR/noctalia-greeter/greeter.toml"
readonly TRACKED_SYNC_DEFAULTS="$SCRIPT_DIR/noctalia-greeter/sync.toml"
readonly TRACKED_TMPFILES="$SCRIPT_DIR/noctalia-greeter/noctalia-greeter.conf"
readonly GREETD_USER="greetd"
readonly GREETER_STATE_DIR="/var/lib/noctalia-greeter"

[[ "$LOGIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || {
    echo "error: invalid login user: $LOGIN_USER" >&2
    exit 2
}
getent passwd "$LOGIN_USER" >/dev/null || {
    echo "error: login user does not exist: $LOGIN_USER" >&2
    exit 2
}
getent passwd "$GREETD_USER" >/dev/null || {
    echo "error: greeter account does not exist: $GREETD_USER" >&2
    exit 2
}
command -v python3 >/dev/null || {
    echo "error: python3 is required to validate tracked greeter TOML." >&2
    exit 2
}
command -v runuser >/dev/null || {
    echo "error: runuser is required to install initial greeter state safely." >&2
    exit 2
}

# Bind validation and every later read to one root-owned snapshot. The source
# checkout may be writable by the invoking account while this script runs as
# root, so never validate a tracked pathname and then reopen it for installation.
snapshot_dir="$(mktemp -d)"
rendered_config="$(mktemp)"
trap 'rm -rf -- "$snapshot_dir"; rm -f -- "$rendered_config"' EXIT
chmod 0755 "$snapshot_dir"
python3 - \
    "$TRACKED_CONFIG" "$snapshot_dir/greeter.toml" \
    "$TRACKED_SYNC_DEFAULTS" "$snapshot_dir/sync.toml" \
    "$TRACKED_TMPFILES" "$snapshot_dir/noctalia-greeter.conf" <<'PY'
import os
import stat
import sys

for source, destination in zip(sys.argv[1::2], sys.argv[2::2], strict=True):
    try:
        source_fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError as error:
        raise SystemExit(f"error: cannot securely open tracked input {source}: {error}") from error

    try:
        if not stat.S_ISREG(os.fstat(source_fd).st_mode):
            raise SystemExit(f"error: tracked input is not a regular file: {source}")
        destination_fd = os.open(
            destination,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
        )
        try:
            with os.fdopen(source_fd, "rb", closefd=False) as source_file:
                with os.fdopen(destination_fd, "wb", closefd=False) as destination_file:
                    destination_file.write(source_file.read())
            os.fchmod(destination_fd, 0o644)
        finally:
            os.close(destination_fd)
    finally:
        os.close(source_fd)
PY

readonly SNAPSHOT_CONFIG="$snapshot_dir/greeter.toml"
readonly SNAPSHOT_SYNC_DEFAULTS="$snapshot_dir/sync.toml"
readonly SNAPSHOT_TMPFILES="$snapshot_dir/noctalia-greeter.conf"

python3 - "$SNAPSHOT_CONFIG" "$SNAPSHOT_SYNC_DEFAULTS" "$SNAPSHOT_TMPFILES" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as config_file:
    config = tomllib.load(config_file)
with open(sys.argv[2], "rb") as sync_file:
    sync = tomllib.load(sync_file)

if not isinstance(config.get("user", {}).get("default"), str):
    raise SystemExit("error: greeter.toml must define user.default as a string")

actions = sync.get("session", {}).get("actions")
expected_actions = [
    {"action": "shutdown", "label": "Shut down", "glyph": "power"},
    {"action": "reboot", "label": "Restart", "glyph": "reload"},
]
if actions != expected_actions:
    raise SystemExit("error: sync.toml does not contain the expected power actions")

expected_tmpfiles = (
    "# Override the upstream /usr/local/lib rule, which assumes greeter:greeter.\n"
    "d /var/lib/noctalia-greeter 0750 greetd greetd -\n"
)
with open(sys.argv[3], encoding="utf-8") as tmpfiles_file:
    if tmpfiles_file.read() != expected_tmpfiles:
        raise SystemExit("error: unexpected noctalia-greeter tmpfiles directive")
PY

# /var/lib is root-owned, so reject a replaced state-directory entry before
# reading anything beneath it or invoking upstream's privileged setup.
if [[ -e "$GREETER_STATE_DIR" || -L "$GREETER_STATE_DIR" ]]; then
    [[ -d "$GREETER_STATE_DIR" && ! -L "$GREETER_STATE_DIR" ]] || {
        echo "error: greeter state path is not a regular directory: $GREETER_STATE_DIR" >&2
        exit 1
    }
fi

# Upstream migrates state.toml and runtime greeter.toml keys, and preserves an
# existing regular sync.toml. Identify a truly clean install before setup so its
# seed can be created exclusively without displacing existing or legacy state.
seed_initial_sync=true
for state_file in sync.toml state.toml appearance.json greeter.toml; do
    if [[ -e "$GREETER_STATE_DIR/$state_file" || -L "$GREETER_STATE_DIR/$state_file" ]]; then
        seed_initial_sync=false
        break
    fi
done
install -d -m 0755 /etc/tmpfiles.d
install -m 0644 "$SNAPSHOT_TMPFILES" /etc/tmpfiles.d/noctalia-greeter.conf

if [[ "$seed_initial_sync" == true ]]; then
    install -d -m 0750 -o "$GREETD_USER" -g "$GREETD_USER" "$GREETER_STATE_DIR"

    if runuser -u "$GREETD_USER" -- python3 -c '
import errno
import os
import secrets
import sys

source, destination = sys.argv[1:]
state_directory, destination_name = os.path.split(destination)
directory_fd = os.open(state_directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
temporary_name = None
try:
    for _ in range(128):
        candidate = f".{destination_name}.seed-{os.getpid()}-{secrets.token_hex(8)}"
        try:
            temporary_fd = os.open(
                candidate,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o640,
                dir_fd=directory_fd,
            )
            temporary_name = candidate
            break
        except FileExistsError:
            continue
    else:
        raise RuntimeError("could not allocate a unique greeter seed file")

    with os.fdopen(temporary_fd, "wb") as temporary_file, open(source, "rb") as source_file:
        temporary_file.write(source_file.read())
        temporary_file.flush()
        os.fsync(temporary_file.fileno())

    try:
        os.link(
            temporary_name,
            destination_name,
            src_dir_fd=directory_fd,
            dst_dir_fd=directory_fd,
            follow_symlinks=False,
        )
    except FileExistsError:
        raise SystemExit(errno.EEXIST)
    os.fsync(directory_fd)
finally:
    if temporary_name is not None:
        try:
            os.unlink(temporary_name, dir_fd=directory_fd)
        except FileNotFoundError:
            pass
    os.close(directory_fd)
' "$SNAPSHOT_SYNC_DEFAULTS" "$GREETER_STATE_DIR/sync.toml"; then
        :
    else
        seed_status=$?
        if [[ "$seed_status" -ne 17 ]]; then
            echo "error: failed to create initial greeter sync state." >&2
            exit "$seed_status"
        fi
    fi
fi

GREETER_USER="$GREETD_USER" "$OFFICIAL_SETUP"

sed "/^\[user\]$/,/^\[/ s/^default = \"[^\"]*\"/default = \"$LOGIN_USER\"/" \
    "$SNAPSHOT_CONFIG" > "$rendered_config"
chmod 0644 "$rendered_config"
runuser -u "$GREETD_USER" -- \
    install -m 0640 "$rendered_config" "$GREETER_STATE_DIR/greeter.toml"

cp -a /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>/dev/null || true
install -m 0644 /dev/stdin /etc/greetd/config.toml <<GREETD_CONFIG
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/noctalia-greeter-session -- --session Niri --user $LOGIN_USER"
user = "greetd"
GREETD_CONFIG

echo "Noctalia Greeter system configuration staged. GDM and greetd service state is unchanged."
