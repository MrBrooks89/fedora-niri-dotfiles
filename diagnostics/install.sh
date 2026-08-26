#!/usr/bin/env bash
set -Eeuo pipefail

readonly script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly unit_dir="$HOME/.config/systemd/user"
readonly repo_dir="$(git -C "$script_dir" rev-parse --show-toplevel)"
source "$script_dir/lib.sh"
github_repo="$(resolve_github_repo "$repo_dir")" || {
    echo "ERROR: Git origin must be a GitHub owner/repository URL." >&2
    exit 1
}
readonly github_repo

command -v gh >/dev/null || {
    echo "ERROR: Install GitHub CLI first: sudo dnf install gh" >&2
    exit 1
}
command -v codex >/dev/null || {
    echo "ERROR: Install Codex first, then sign in with ChatGPT: codex login" >&2
    exit 1
}
codex login status 2>&1 | grep -q '^Logged in using ChatGPT$' || {
    echo "ERROR: Authenticate Codex with ChatGPT first: codex login" >&2
    exit 1
}
gh auth status --hostname github.com >/dev/null 2>&1 || {
    echo "ERROR: Authenticate first: gh auth login --hostname github.com" >&2
    exit 1
}
github_login="$(gh api user --jq .login)"
github_owner="${github_repo%%/*}"
if [[ "${github_owner,,}" != "${github_login,,}" ]]; then
    echo "ERROR: Diagnostics must target a repository owned by the logged-in GitHub user." >&2
    echo "       GitHub user: $github_login" >&2
    echo "       origin repo: $github_repo" >&2
    echo "Fork the repository and set origin to your fork before enabling diagnostics." >&2
    exit 1
fi

mkdir -p "$unit_dir" "$HOME/.local/bin"
ln -sfn "$script_dir/collect-incident.sh" "$HOME/.local/bin/diagnose-workstation"
ln -sfn "$script_dir/run-local-codex.sh" "$HOME/.local/bin/diagnose-workstation-with-codex"
ln -sfn "$script_dir/systemd/fedora-niri-diagnostics.service" \
    "$unit_dir/fedora-niri-diagnostics.service"
ln -sfn "$script_dir/systemd/fedora-niri-diagnostics.timer" \
    "$unit_dir/fedora-niri-diagnostics.timer"

systemctl --user daemon-reload
systemctl --user enable --now fedora-niri-diagnostics.timer

echo "Automatic diagnostics enabled."
echo "Test locally: diagnose-workstation --dry-run --force"
echo "Timer status: systemctl --user status fedora-niri-diagnostics.timer"
