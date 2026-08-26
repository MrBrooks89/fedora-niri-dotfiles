#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "error: run as root (use sudo)." >&2
    exit 1
fi

if [[ $# -ne 1 || ! -x "$1" ]]; then
    echo "Usage: sudo $0 /path/to/noctalia-greeter/scripts/setup_greeter_system.sh" >&2
    exit 2
fi

readonly OFFICIAL_SETUP="$1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TRACKED_CONFIG="$SCRIPT_DIR/noctalia-greeter/greeter.toml"
readonly GREETD_USER="greetd"

GREETER_USER="$GREETD_USER" "$OFFICIAL_SETUP"

install -d -m 0750 -o "$GREETD_USER" -g "$GREETD_USER" /var/lib/noctalia-greeter
install -m 0640 -o "$GREETD_USER" -g "$GREETD_USER" \
    "$TRACKED_CONFIG" /var/lib/noctalia-greeter/greeter.toml

cp -a /etc/greetd/config.toml /etc/greetd/config.toml.bak 2>/dev/null || true
install -m 0644 /dev/stdin /etc/greetd/config.toml <<'GREETD_CONFIG'
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/noctalia-greeter-session -- --session Niri --user mrbrooks"
user = "greetd"
GREETD_CONFIG

echo "Noctalia Greeter system configuration staged. GDM and greetd service state is unchanged."
