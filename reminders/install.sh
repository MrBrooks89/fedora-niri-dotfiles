#!/usr/bin/env bash
set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

command -v systemctl >/dev/null 2>&1 || {
    echo "ERROR: systemd is required." >&2
    exit 1
}
command -v notify-send >/dev/null 2>&1 || {
    echo "ERROR: Install libnotify first: sudo dnf install libnotify" >&2
    exit 1
}

mkdir -p "$HOME/.local/bin"
ln -sfn "$script_dir/fedora-reminder" "$HOME/.local/bin/fedora-reminder"

echo "Fedora reminder CLI installed at $HOME/.local/bin/fedora-reminder"
echo "Try: fedora-reminder add 10m 'Check the oven'"
