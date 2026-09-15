#!/usr/bin/env bash
set -Eeuo pipefail

readonly script_path="$(readlink -f -- "${BASH_SOURCE[0]}")"
readonly script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
readonly repo_dir="$(git -C "$script_dir" rev-parse --show-toplevel)"
source "$script_dir/lib.sh"
github_repo="$(resolve_github_repo "$repo_dir")" || {
    echo "ERROR: Git origin must be a GitHub owner/repository URL." >&2
    exit 1
}
readonly github_repo
readonly state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-niri-diagnostics"

report_file=""
issue_number=""
report_hash=""

usage() {
    cat <<'EOF'
Usage: run-local-codex.sh --report FILE --issue NUMBER --hash SHA256

Run Codex locally with the current user's ChatGPT login, prepare any supported
fix in an isolated Git worktree, and publish either an issue comment or a PR.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --report) report_file="${2:?--report requires a file}"; shift ;;
        --issue) issue_number="${2:?--issue requires a number}"; shift ;;
        --hash) report_hash="${2:?--hash requires a value}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

[[ -r "$report_file" ]] || { echo "ERROR: Diagnostic report is not readable." >&2; exit 1; }
[[ "$issue_number" =~ ^[0-9]+$ ]] || { echo "ERROR: Invalid issue number." >&2; exit 1; }
[[ "$report_hash" =~ ^[[:xdigit:]]{64}$ ]] || { echo "ERROR: Invalid report hash." >&2; exit 1; }

for command_name in codex gh git flock; do
    command -v "$command_name" >/dev/null || {
        echo "ERROR: Required command is missing: $command_name" >&2
        exit 1
    }
done
codex login status 2>&1 | rg -q '^Logged in using ChatGPT$' || {
    echo "ERROR: Codex must be logged in with ChatGPT: codex login" >&2
    exit 1
}
gh auth status --hostname github.com >/dev/null 2>&1 || {
    echo "ERROR: GitHub authentication is unavailable." >&2
    exit 1
}

mkdir -p "$state_dir"
exec 9>"$state_dir/local-codex.lock"
if ! flock -n 9; then
    echo "Another local Codex diagnosis is already running; skipping issue #$issue_number."
    exit 0
fi

run_dir="$(mktemp -d --tmpdir fedora-niri-codex.XXXXXX)"
worktree="$run_dir/worktree"
prompt_file="$run_dir/prompt.md"
result_file="$run_dir/result.md"
cleanup() {
    git -C "$repo_dir" worktree remove --force "$worktree" >/dev/null 2>&1 || true
    rm -rf -- "$run_dir"
}
trap cleanup EXIT

git -C "$repo_dir" fetch --quiet origin main
git -C "$repo_dir" worktree add --quiet --detach "$worktree" origin/main

cat "$script_dir/codex-prompt.md" > "$prompt_file"
head -c 50000 "$report_file" >> "$prompt_file"

if ! codex exec \
    --cd "$worktree" \
    --sandbox workspace-write \
    --ephemeral \
    --color never \
    --output-last-message "$result_file" \
    - < "$prompt_file"; then
    gh issue comment "$issue_number" --repo "$github_repo" --body \
        "Local Codex diagnosis failed before producing a proposal. Run \`journalctl --user -u fedora-niri-diagnostics.service\` locally for details."
    exit 1
fi

if [[ -z "$(git -C "$worktree" status --porcelain)" ]]; then
    if [[ -s "$result_file" ]]; then
        gh issue comment "$issue_number" --repo "$github_repo" --body-file "$result_file"
    else
        gh issue comment "$issue_number" --repo "$github_repo" --body \
            "Local Codex found no supported repository change and returned no additional diagnosis."
    fi
    exit 0
fi

git -C "$worktree" add --all
if git -C "$worktree" diff --cached --name-only | \
    rg -qi '(^|/)(\.env($|\.)|auth\.json$|credentials($|\.)|pending-report\.md$)'; then
    gh issue comment "$issue_number" --repo "$github_repo" --body \
        "Local Codex produced a change containing a prohibited credential or diagnostic-state filename. Nothing was pushed."
    exit 1
fi

branch="codex/workstation-diagnostic-${issue_number}-${report_hash:0:12}"
git -C "$worktree" switch -c "$branch"
git -C "$worktree" \
    -c user.name="local-codex-agent" \
    -c user.email="local-codex-agent@users.noreply.github.com" \
    commit -m "Diagnose workstation incident #${issue_number}"
git -C "$worktree" push --set-upstream origin "$branch"

{
    echo "Local Codex proposal for #${issue_number}."
    echo
    echo "This ran in an isolated worktree. Review and test before merging."
    echo
    [[ -s "$result_file" ]] && cat "$result_file"
} > "$run_dir/pr-body.md"

pr_url="$(gh pr create \
    --repo "$github_repo" \
    --base main \
    --head "$branch" \
    --title "Fix workstation diagnostic #${issue_number}" \
    --body-file "$run_dir/pr-body.md")"
gh issue comment "$issue_number" --repo "$github_repo" --body "Proposed fix: $pr_url"
echo "Created pull request: $pr_url"
