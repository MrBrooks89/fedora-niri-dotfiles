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
if ! command -v canberra-gtk-play >/dev/null 2>&1; then
    echo "WARNING: Audible reminders are unavailable." >&2
    echo "         Install them with: sudo dnf install libcanberra-gtk3 sound-theme-freedesktop" >&2
elif command -v rpm >/dev/null 2>&1 && ! rpm -q sound-theme-freedesktop >/dev/null 2>&1; then
    echo "WARNING: The Freedesktop sound theme is missing; reminders will remain visual." >&2
    echo "         Install it with: sudo dnf install sound-theme-freedesktop" >&2
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$script_dir/fedora-reminder" "$HOME/.local/bin/fedora-reminder"

echo "Fedora reminder CLI installed at $HOME/.local/bin/fedora-reminder"
echo "Try: fedora-reminder add 10m 'Check the oven'"
