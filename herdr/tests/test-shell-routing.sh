#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/outside"

cat >"$TMP/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf 'session=%s argc=%s' "${HERDR_SESSION:-default}" "$#"
if (( $# > 0 )); then
    printf ' arg=<%s>' "$@"
fi
printf '\n'
EOF
chmod 700 "$TMP/bin/herdr"
cat >"$TMP/bin/starship" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 700 "$TMP/bin/starship"

run_zsh() {
    env -u HERDR_ENV -u HERDR_SESSION -u HERDR_SOCKET_PATH \
        PATH="$TMP/bin:/usr/bin:/bin" zsh -f -c \
        'source "$1/herdr/shell-integration.zsh"; cd -- "$2"; shift 2; herdr "$@"' \
        test "$ROOT" "$@"
}

[[ "$(run_zsh "$ROOT")" == "session=fedora-niri-dotfiles argc=0" ]]
[[ "$(run_zsh "$ROOT/herdr")" == "session=fedora-niri-dotfiles argc=0" ]]
[[ "$(run_zsh "$TMP/outside")" == "session=default argc=0" ]]
[[ "$(run_zsh "$ROOT" --help 'two words')" == "session=default argc=2 arg=<--help> arg=<two words>" ]]
payload='$(touch should-not-exist); | `false` * ?'
[[ "$(run_zsh "$ROOT" --flag "$payload")" == "session=default argc=2 arg=<--flag> arg=<$payload>" ]]
[[ ! -e "$ROOT/should-not-exist" ]]

mkdir -p "$TMP/home"
ln -s "$ROOT/.zshrc" "$TMP/home/.zshrc"
symlink_result="$(env -u HERDR_ENV -u HERDR_SESSION -u HERDR_SOCKET_PATH HOME="$TMP/home" PATH="$TMP/bin:/usr/bin:/bin" zsh -f -c 'source "$HOME/.zshrc"; cd -- "$1/herdr"; herdr' test "$ROOT")"
[[ "$symlink_result" == "session=fedora-niri-dotfiles argc=0" ]]

git -C "$TMP" init -q alternate
[[ "$(run_zsh "$TMP/alternate")" == "session=default argc=0" ]]

space_repo="$TMP/checkout with spaces"
git clone -q "$ROOT" "$space_repo"
cp "$ROOT/herdr/shell-integration.zsh" "$space_repo/herdr/shell-integration.zsh"
cp "$ROOT/herdr/dispatch.sh" "$space_repo/herdr/dispatch.sh"
space_result="$(env -u HERDR_ENV -u HERDR_SESSION -u HERDR_SOCKET_PATH PATH="$TMP/bin:/usr/bin:/bin" zsh -f -c 'source "$1/herdr/shell-integration.zsh"; cd -- "$1/herdr"; herdr' test "$space_repo")"
[[ "$space_result" == "session=fedora-niri-dotfiles argc=0" ]]

linked_worktree="$TMP/linked worktree"
git -C "$space_repo" worktree add -q --detach "$linked_worktree" HEAD
[[ "$(run_zsh "$linked_worktree")" == "session=default argc=0" ]]

set +e
HERDR_ENV=1 PATH="$TMP/bin:/usr/bin:/bin" zsh -f -c \
    'source "$1/herdr/shell-integration.zsh"; cd -- "$1"; herdr' \
    test "$ROOT" >"$TMP/nested.out" 2>"$TMP/nested.err"
status=$?
set -e
[[ $status -eq 2 ]]
grep -Fq 'Already inside Herdr' "$TMP/nested.err"
