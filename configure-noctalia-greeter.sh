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
readonly TRACKED_TMPFILES="$SCRIPT_DIR/noctalia-greeter/noctalia-greeter.conf"
readonly GREETD_USER="greetd"

[[ "$LOGIN_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || {
    echo "error: invalid login user: $LOGIN_USER" >&2
    exit 2
}
getent passwd "$LOGIN_USER" >/dev/null || {
    echo "error: login user does not exist: $LOGIN_USER" >&2
    exit 2
}

install -d -m 0755 /etc/tmpfiles.d
install -m 0644 "$TRACKED_TMPFILES" /etc/tmpfiles.d/noctalia-greeter.conf
GREETER_USER="$GREETD_USER" "$OFFICIAL_SETUP"

install -d -m 0750 -o "$GREETD_USER" -g "$GREETD_USER" /var/lib/noctalia-greeter
if [[ -e /var/lib/noctalia-greeter/sync.toml ]]; then
    chown "$GREETD_USER:$GREETD_USER" /var/lib/noctalia-greeter/sync.toml
    chmod 0640 /var/lib/noctalia-greeter/sync.toml
fi
rendered_config="$(mktemp)"
trap 'rm -f -- "$rendered_config"' EXIT
sed "/^\[user\]$/,/^\[/ s/^default = \"[^\"]*\"/default = \"$LOGIN_USER\"/" \
    "$TRACKED_CONFIG" > "$rendered_config"
install -m 0640 -o "$GREETD_USER" -g "$GREETD_USER" \
    "$rendered_config" /var/lib/noctalia-greeter/greeter.toml

cp -a /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>/dev/null || true
install -m 0644 /dev/stdin /etc/greetd/config.toml <<GREETD_CONFIG
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/noctalia-greeter-session -- --session Niri --user $LOGIN_USER"
user = "greetd"
GREETD_CONFIG

echo "Noctalia Greeter system configuration staged. GDM and greetd service state is unchanged."
