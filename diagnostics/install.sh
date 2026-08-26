#!/usr/bin/env bash
set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly unit_dir="$HOME/.config/systemd/user"

command -v gh >/dev/null || {
    echo "ERROR: Install GitHub CLI first: sudo dnf install gh" >&2
    exit 1
}
gh auth status --hostname github.com >/dev/null 2>&1 || {
    echo "ERROR: Authenticate first: gh auth login --hostname github.com" >&2
    exit 1
}

mkdir -p "$unit_dir" "$HOME/.local/bin"
ln -sfn "$script_dir/collect-incident.sh" "$HOME/.local/bin/diagnose-workstation"
ln -sfn "$script_dir/systemd/fedora-niri-diagnostics.service" \
    "$unit_dir/fedora-niri-diagnostics.service"
ln -sfn "$script_dir/systemd/fedora-niri-diagnostics.timer" \
    "$unit_dir/fedora-niri-diagnostics.timer"

systemctl --user daemon-reload
systemctl --user enable --now fedora-niri-diagnostics.timer

echo "Automatic diagnostics enabled."
echo "Test locally: diagnose-workstation --dry-run --force"
echo "Timer status: systemctl --user status fedora-niri-diagnostics.timer"
