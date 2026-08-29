#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

usage() {
    cat <<'EOF'
Usage:
  handoff.sh init TASK_ID
  handoff.sh put TASK_ID ROLE MARKDOWN_FILE
  handoff.sh show TASK_ID [ROLE]

Stores bounded task handoffs outside Git under XDG_STATE_HOME. Input files must
be regular, non-symlink Markdown files no larger than 64 KiB.
EOF
}

[[ $# -ge 2 ]] || { usage >&2; exit 2; }
ACTION="$1"
TASK_ID="$2"
[[ "$TASK_ID" =~ ^[a-z0-9][a-z0-9._-]{0,63}$ ]] || { echo "Invalid task ID" >&2; exit 2; }

STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-niri-dotfiles/herdr"
TASK_DIR="$STATE_ROOT/tasks/$TASK_ID"
mkdir -p -- "$STATE_ROOT/tasks"
chmod 700 -- "$STATE_ROOT" "$STATE_ROOT/tasks"
exec 9>"$STATE_ROOT/.lock"
flock 9

case "$ACTION" in
    init)
        [[ $# -eq 2 ]] || { usage >&2; exit 2; }
        mkdir -p -- "$TASK_DIR/handoffs"
        chmod 700 -- "$TASK_DIR" "$TASK_DIR/handoffs"
        if [[ ! -e "$TASK_DIR/task.json" ]]; then
            temporary="$(mktemp --tmpdir="$TASK_DIR" .task.json.XXXXXX)"
            jq -n --arg task "$TASK_ID" --arg created "$(date --iso-8601=seconds)" \
                '{schema_version:1, task:$task, created_at:$created}' >"$temporary"
            chmod 600 -- "$temporary"
            mv -T -- "$temporary" "$TASK_DIR/task.json"
        fi
        printf '%s\n' "$TASK_DIR"
        ;;
    put)
        [[ $# -eq 4 ]] || { usage >&2; exit 2; }
        ROLE="$3"
        SOURCE="$4"
        [[ "$ROLE" =~ ^(coordinator|implementation|integration|validation|security|release)$ ]] || {
            echo "Invalid role" >&2; exit 2;
        }
        [[ -f "$SOURCE" && ! -L "$SOURCE" ]] || { echo "Input must be a regular non-symlink file" >&2; exit 1; }
        SIZE="$(stat -c %s -- "$SOURCE")"
        (( SIZE <= 65536 )) || { echo "Input exceeds 64 KiB" >&2; exit 1; }
        mkdir -p -- "$TASK_DIR/handoffs"
        chmod 700 -- "$TASK_DIR" "$TASK_DIR/handoffs"
        TARGET="$TASK_DIR/handoffs/$ROLE.md"
        temporary="$(mktemp --tmpdir="$TASK_DIR/handoffs" ".$ROLE.md.XXXXXX")"
        install -m 600 -- "$SOURCE" "$temporary"
        mv -T -- "$temporary" "$TARGET"
        printf '%s  %s\n' "$(sha256sum -- "$TARGET" | cut -d' ' -f1)" "$TARGET"
        ;;
    show)
        [[ $# -le 3 ]] || { usage >&2; exit 2; }
        if [[ $# -eq 3 ]]; then
            [[ "$3" =~ ^(coordinator|implementation|integration|validation|security|release)$ ]] || {
                echo "Invalid role" >&2; exit 2;
            }
            exec sed -n '1,1200p' "$TASK_DIR/handoffs/$3.md"
        fi
        find "$TASK_DIR/handoffs" -maxdepth 1 -type f -name '*.md' -printf '%f\n' | sort
        ;;
    *) usage >&2; exit 2 ;;
esac
