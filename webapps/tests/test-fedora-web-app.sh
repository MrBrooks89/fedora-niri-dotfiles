#!/usr/bin/env bash
set -Eeuo pipefail

readonly ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly WEB_APP_SOURCE="$ROOT/webapps/fedora-web-app"
readonly TEMP_DIR="$(mktemp -d)"
readonly TEST_HOME="$TEMP_DIR/home with spaces"
readonly TEST_DATA="$TEMP_DIR/data home"
readonly WEB_APP="$TEMP_DIR/manager with spaces/fedora-web-app"

trap 'rm -rf -- "$TEMP_DIR"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

expect_failure() {
    if "$@" >/dev/null 2>&1; then
        fail "Expected failure: $*"
    fi
}

mkdir -p "$TEST_HOME" "$TEST_DATA" "${WEB_APP%/*}"
cp -- "$WEB_APP_SOURCE" "$WEB_APP"
chmod +x "$WEB_APP"

env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id outlook --name Outlook --url https://outlook.cloud.microsoft/mail/

desktop_file="$TEST_DATA/applications/fedora-web-app-outlook.desktop"
config_file="$TEST_DATA/fedora-web-apps/fedora-web-app-outlook.tsv"
[[ -f "$desktop_file" ]] || fail "Outlook desktop entry was not created."
[[ -f "$config_file" ]] || fail "Outlook metadata was not created."
grep -Fx 'Name=Outlook' "$desktop_file" >/dev/null || fail "Desktop name mismatch."
grep -Fx $'Outlook\thttps://outlook.cloud.microsoft/mail/' "$config_file" >/dev/null || fail "Metadata mismatch."
grep -Fx "Exec=\"$WEB_APP\" launch --id outlook" "$desktop_file" >/dev/null || \
    fail "Desktop command must quote the manager path."

if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$desktop_file"
fi

expect_failure env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id 'bad;id' --name Outlook --url https://outlook.cloud.microsoft/mail/
expect_failure env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id injection --name $'Bad\nExec=touch /tmp/pwned' --url https://example.com/
expect_failure env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id injection --name Portal --url $'https://example.com/\nExec=touch /tmp/pwned'
expect_failure env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id control --name Portal --url $'https://example.com/\a'
expect_failure env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id scheme --name Portal --url 'javascript:alert(1)'
expect_failure env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id credentials --name Portal --url https://user@example.com/

env HOME="$TEST_HOME" XDG_DATA_HOME='relative-data' "$WEB_APP" add \
    --id fallback --name 'Fallback XDG' --url https://example.com/
[[ -f "$TEST_HOME/.local/share/applications/fedora-web-app-fallback.desktop" ]] || \
    fail "Relative XDG_DATA_HOME was not safely ignored."

browser_dir="$TEMP_DIR/browser bin"
mkdir -p "$browser_dir"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$@" > "$WEB_APP_TEST_LOG"' > "$browser_dir/chromium-browser"
chmod +x "$browser_dir/chromium-browser"
selected_browser="$(PATH="$browser_dir:/usr/bin:/bin" "$WEB_APP" --print-browser)"
[[ "$selected_browser" == "$browser_dir/chromium-browser" ]] || fail "Chromium browser resolution mismatch."

launch_log="$TEMP_DIR/browser-arguments"
env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" \
    WEB_APP_BROWSER="$browser_dir/chromium-browser" WEB_APP_TEST_LOG="$launch_log" \
    PATH="$browser_dir:/usr/bin:/bin" "$WEB_APP" launch --id outlook
grep -Fx -- '--ozone-platform=wayland' "$launch_log" >/dev/null || fail "Wayland flag missing."
grep -Fx -- '--app=https://outlook.cloud.microsoft/mail/' "$launch_log" >/dev/null || fail "App URL argument mismatch."

list_output="$(env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" list)"
[[ "$list_output" == *$'outlook\tOutlook\thttps://outlook.cloud.microsoft/mail/'* ]] || fail "List output mismatch."
env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" remove --id outlook
[[ ! -e "$desktop_file" && ! -e "$config_file" ]] || fail "Remove did not delete managed files."

printf 'webapps: all tests passed\n'
