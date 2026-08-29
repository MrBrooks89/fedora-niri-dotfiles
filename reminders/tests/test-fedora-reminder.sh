#!/usr/bin/env bash
set -Eeuo pipefail

readonly test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
readonly fake_bin="$test_dir/bin"
readonly calls="$test_dir/systemctl.calls"
mkdir -p "$fake_bin" "$test_dir/home"

cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$REMINDER_TEST_CALLS"
EOF
cat >"$fake_bin/notify-send" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$REMINDER_TEST_NOTIFY"
EOF
chmod +x "$fake_bin/systemctl" "$fake_bin/notify-send"

export HOME="$test_dir/home"
export XDG_STATE_HOME="$test_dir/state"
export XDG_CONFIG_HOME="$test_dir/config"
export REMINDER_TEST_CALLS="$calls"
export REMINDER_TEST_NOTIFY="$test_dir/notify.calls"
export PATH="$fake_bin:/usr/bin:/bin"

reminder="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/fedora-reminder"

"$reminder" add 2m "Test the reminder" >"$test_dir/add.out"
id="$(sed -n 's/^Created reminder \([^ ]*\) .*/\1/p' "$test_dir/add.out")"
[[ "$id" =~ ^[0-9]{8}T[0-9]{6}-[0-9]+-[0-9]+$ ]]
[[ -f "$XDG_STATE_HOME/fedora-reminders/$id" ]]
grep -Fq 'message=Test the reminder' "$XDG_STATE_HOME/fedora-reminders/$id"
grep -Fq 'Persistent=true' "$XDG_CONFIG_HOME/systemd/user/fedora-reminder-$id.timer"
grep -Fq "ExecStart=" "$XDG_CONFIG_HOME/systemd/user/fedora-reminder-$id.service"
grep -Fq "start fedora-reminder-$id.timer" "$calls"
if command -v systemd-analyze >/dev/null 2>&1; then
    systemd-analyze verify \
        "$XDG_CONFIG_HOME/systemd/user/fedora-reminder-$id.service" \
        "$XDG_CONFIG_HOME/systemd/user/fedora-reminder-$id.timer"
fi

"$reminder" list >"$test_dir/list.out"
grep -Fq "$id" "$test_dir/list.out"
grep -Fq 'Test the reminder' "$test_dir/list.out"

"$reminder" deliver "$id"
grep -Fq 'Reminder Test the reminder' "$REMINDER_TEST_NOTIFY"
[[ ! -e "$XDG_STATE_HOME/fedora-reminders/$id" ]]
[[ ! -e "$XDG_CONFIG_HOME/systemd/user/fedora-reminder-$id.timer" ]]

"$reminder" add 5m "First" >"$test_dir/first.out"
first="$(sed -n 's/^Created reminder \([^ ]*\) .*/\1/p' "$test_dir/first.out")"
"$reminder" add 1h "Second" >"$test_dir/second.out"
second="$(sed -n 's/^Created reminder \([^ ]*\) .*/\1/p' "$test_dir/second.out")"
"$reminder" cancel "$first" >"$test_dir/cancel.out"
[[ ! -e "$XDG_STATE_HOME/fedora-reminders/$first" ]]
[[ -e "$XDG_STATE_HOME/fedora-reminders/$second" ]]
"$reminder" clear >"$test_dir/clear.out"
grep -Fq 'Cleared 1 reminder(s).' "$test_dir/clear.out"
[[ ! -e "$XDG_STATE_HOME/fedora-reminders/$second" ]]

if "$reminder" add nope "Bad duration" >/dev/null 2>&1; then
    echo "invalid duration unexpectedly succeeded" >&2
    exit 1
fi

echo "fedora-reminder tests passed"
