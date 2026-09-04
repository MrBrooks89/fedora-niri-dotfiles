#!/usr/bin/env bash
set -Eeuo pipefail

readonly script_path="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
readonly repo_dir="$(git -C "$script_dir" rev-parse --show-toplevel)"
readonly state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-niri-diagnostics"
source "$script_dir/lib.sh"

report_file=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --report) report_file="${2:?--report requires a file}"; shift ;;
        -h|--help) echo 'Usage: run-click-diagnosis.sh --report FILE'; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

[[ -n "$report_file" ]] || {
    echo 'ERROR: --report FILE is required.' >&2
    exit 2
}

report_file="$(readlink -f -- "$report_file")"
case "$report_file" in
    "$state_dir"/commands/*/report.md) ;;
    *) echo 'ERROR: Refusing a report outside the diagnostics state directory.' >&2; exit 1 ;;
esac
[[ -r "$report_file" ]] || { echo 'ERROR: Diagnostic report is not readable.' >&2; exit 1; }

for command_name in codex git flock; do
    command -v "$command_name" >/dev/null || {
        echo "ERROR: Required command is missing: $command_name" >&2
        exit 1
    }
done
codex login status 2>&1 | rg -q '^Logged in using ChatGPT$' || {
    echo 'ERROR: Codex must be logged in with ChatGPT: codex login' >&2
    exit 1
}

mkdir -p "$state_dir"
exec 9>"$state_dir/local-codex.lock"
flock -n 9 || { echo 'Another local Codex diagnosis is already running.'; exit 0; }

run_dir="$(mktemp -d --tmpdir fedora-niri-click-diagnosis.XXXXXX)"
worktree="$run_dir/worktree"
prompt_file="$run_dir/prompt.md"
result_file="$run_dir/result.md"
cleanup() {
    git -C "$repo_dir" worktree remove --force "$worktree" >/dev/null 2>&1 || true
    rm -rf -- "$run_dir"
}
trap cleanup EXIT

git -C "$repo_dir" worktree add --quiet --detach "$worktree" HEAD
cat "$script_dir/command-prompt.md" > "$prompt_file"
head -c 50000 "$report_file" >> "$prompt_file"

echo 'Codex is diagnosing the failure...'
echo
codex exec \
    --cd "$worktree" \
    --sandbox workspace-write \
    --ephemeral \
    --color never \
    --output-last-message "$result_file" \
    - < "$prompt_file"

if [[ -z "$(git -C "$worktree" status --porcelain)" ]]; then
    echo
    echo 'Diagnosis'
    echo '========='
    if [[ -s "$result_file" ]]; then
        cat "$result_file"
    else
        echo 'Codex returned no diagnosis.'
    fi
    exit 0
fi

command -v gh >/dev/null || {
    echo 'Codex prepared a repository fix, but GitHub CLI is unavailable.' >&2
    exit 1
}
gh auth status --hostname github.com >/dev/null 2>&1 || {
    echo 'Codex prepared a repository fix, but GitHub authentication is unavailable.' >&2
    echo 'Run: gh auth login --hostname github.com' >&2
    exit 1
}
github_repo="$(resolve_github_repo "$repo_dir")" || {
    echo 'ERROR: Git origin is not a supported GitHub repository URL.' >&2
    exit 1
}
github_login="$(gh api user --jq .login)"
github_owner="${github_repo%%/*}"
[[ "${github_owner,,}" == "${github_login,,}" ]] || {
    echo 'ERROR: Refusing to push to a repository not owned by the logged-in GitHub user.' >&2
    exit 1
}

git -C "$worktree" add --all
if git -C "$worktree" diff --cached --name-only | \
    rg -qi '(^|/)(\.env($|\.)|auth\.json$|credentials($|\.)|report\.md$)'; then
    echo 'ERROR: Proposed change contains a prohibited credential or diagnostic filename.' >&2
    exit 1
fi

report_hash="$(sha256sum "$report_file" | cut -d' ' -f1)"
branch="codex/click-diagnosis-${report_hash:0:12}-$(date +%s)"
git -C "$worktree" switch -c "$branch"
git -C "$worktree" \
    -c user.name='local-codex-agent' \
    -c user.email='local-codex-agent@users.noreply.github.com' \
    commit -m 'Fix AI-diagnosed workstation configuration issue'
git -C "$worktree" push --set-upstream origin "$branch"

{
    echo 'Codex found a durable fix in the Fedora Niri dotfiles.'
    echo
    echo 'This change was prepared in an isolated worktree. Review and test it before merging.'
    echo
    [[ -s "$result_file" ]] && cat "$result_file"
} > "$run_dir/pr-body.md"

pr_url="$(gh pr create \
    --repo "$github_repo" \
    --base main \
    --head "$branch" \
    --title 'Fix AI-diagnosed workstation configuration issue' \
    --body-file "$run_dir/pr-body.md")"
echo
echo "Review the proposed fix: $pr_url"
notify-send --app-name='Workstation Diagnostics' \
    'Codex proposed a dotfiles fix' "$pr_url" >/dev/null 2>&1 || true
