#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"

printf '# bounded handoff\n' >"$TMP/input.md"
task_dir="$($ROOT/herdr/handoff.sh init task-123)"
[[ "$task_dir" == "$XDG_STATE_HOME/fedora-niri-dotfiles/herdr/tasks/task-123" ]]
result="$($ROOT/herdr/handoff.sh put task-123 implementation "$TMP/input.md")"
[[ "$result" == *"$task_dir/handoffs/implementation.md" ]]
[[ "$($ROOT/herdr/handoff.sh show task-123 implementation)" == '# bounded handoff' ]]
[[ "$(stat -c %a "$task_dir")" == 700 ]]
[[ "$(stat -c %a "$task_dir/handoffs/implementation.md")" == 600 ]]

ln -s "$TMP/input.md" "$TMP/link.md"
if "$ROOT/herdr/handoff.sh" put task-123 security "$TMP/link.md" >/dev/null 2>&1; then
    echo "symlink input was accepted" >&2
    exit 1
fi
