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
grep -Fx 'Exec=fedora-web-app launch --id outlook' "$desktop_file" >/dev/null || \
    fail "Desktop command must use the fixed manager name."
chmod 0755 "$TEST_DATA" "$TEST_DATA/applications"
env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" add \
    --id safe-modes --name 'Safe Modes' --url https://example.com/ >/dev/null

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

command -v gio >/dev/null 2>&1 || fail "gio is required for the desktop-entry argv round-trip test."
special_manager_dir="$TEMP_DIR/"'manager %f %Z \ " $ `'
special_manager="$special_manager_dir/fedora-web-app"
special_home="$TEMP_DIR/special home"
special_data="$TEMP_DIR/special data"
mkdir -p "$special_manager_dir" "$special_home" "$special_data"
cp -- "$WEB_APP_SOURCE" "$special_manager"
chmod +x "$special_manager"

env HOME="$special_home" XDG_DATA_HOME="$special_data" "$special_manager" add \
    --id probe --name Probe --url https://example.com/
special_desktop="$special_data/applications/fedora-web-app-probe.desktop"
desktop-file-validate "$special_desktop"
grep -Fx 'Exec=fedora-web-app launch --id probe' "$special_desktop" >/dev/null || \
    fail "Special manager path leaked into Exec."
if grep -F '%' "$special_desktop" | grep -F 'Exec=' >/dev/null; then
    fail "Exec must not contain field-code-like percent sequences."
fi
ln -s -- "$special_manager" "$browser_dir/fedora-web-app"

special_launch_log="$TEMP_DIR/special-browser-arguments"
rm -f -- "$special_launch_log"
env HOME="$special_home" XDG_DATA_HOME="$special_data" \
    WEB_APP_BROWSER="$browser_dir/chromium-browser" WEB_APP_TEST_LOG="$special_launch_log" \
    PATH="$browser_dir:/usr/bin:/bin" gio launch "$special_desktop"
for _ in {1..20}; do
    [[ -s "$special_launch_log" ]] && break
    sleep 0.1
done
[[ -s "$special_launch_log" ]] || fail "Desktop-entry launch did not reach the Chromium test double."
grep -Fx -- '--ozone-platform=wayland' "$special_launch_log" >/dev/null || fail "Special-path Wayland flag missing."
grep -Fx -- '--app=https://example.com/' "$special_launch_log" >/dev/null || fail "Special-path manager argv round trip failed."

symlink_data="$TEMP_DIR/symlink data"
symlink_home="$TEMP_DIR/symlink home"
external_target="$TEMP_DIR/external target"
mkdir -p "$symlink_data/applications" "$symlink_data/fedora-web-apps" "$symlink_home" "$external_target"
ln -s -- "$external_target" "$symlink_data/fedora-web-apps/fedora-web-app-final-link.tsv"
expect_failure env HOME="$symlink_home" XDG_DATA_HOME="$symlink_data" "$WEB_APP" add \
    --id final-link --name 'Final Link' --url https://example.com/
[[ -z "$(find "$external_target" -mindepth 1 -print -quit)" ]] || \
    fail "Final destination symlink wrote outside managed storage."

applications_link_data="$TEMP_DIR/applications link data"
applications_link_home="$TEMP_DIR/applications link home"
applications_external="$TEMP_DIR/applications external"
mkdir -p "$applications_link_data" "$applications_link_home" "$applications_external"
ln -s -- "$applications_external" "$applications_link_data/applications"
expect_failure env HOME="$applications_link_home" XDG_DATA_HOME="$applications_link_data" "$WEB_APP" add \
    --id applications-link --name 'Applications Link' --url https://example.com/
[[ -z "$(find "$applications_external" -mindepth 1 -print -quit)" ]] || \
    fail "Symlinked applications directory wrote outside managed storage."

metadata_link_data="$TEMP_DIR/metadata link data"
metadata_link_home="$TEMP_DIR/metadata link home"
metadata_external="$TEMP_DIR/metadata external"
mkdir -p "$metadata_link_data" "$metadata_link_home" "$metadata_external"
ln -s -- "$metadata_external" "$metadata_link_data/fedora-web-apps"
expect_failure env HOME="$metadata_link_home" XDG_DATA_HOME="$metadata_link_data" "$WEB_APP" add \
    --id metadata-link --name 'Metadata Link' --url https://example.com/
[[ -z "$(find "$metadata_external" -mindepth 1 -print -quit)" ]] || \
    fail "Symlinked metadata directory wrote outside managed storage."

unsafe_data="$TEMP_DIR/unsafe writable data"
unsafe_home="$TEMP_DIR/unsafe writable home"
mkdir -p "$unsafe_data" "$unsafe_home"
chmod 0777 "$unsafe_data"
expect_failure env HOME="$unsafe_home" XDG_DATA_HOME="$unsafe_data" "$WEB_APP" add \
    --id unsafe-root --name 'Unsafe Root' --url https://example.com/

unsafe_children_data="$TEMP_DIR/unsafe writable children data"
unsafe_children_home="$TEMP_DIR/unsafe writable children home"
mkdir -p "$unsafe_children_data" "$unsafe_children_home"
env HOME="$unsafe_children_home" XDG_DATA_HOME="$unsafe_children_data" "$WEB_APP" add \
    --id unsafe-children --name 'Unsafe Children' --url https://example.com/ >/dev/null
chmod 0770 "$unsafe_children_data/fedora-web-apps"
expect_failure env HOME="$unsafe_children_home" XDG_DATA_HOME="$unsafe_children_data" "$WEB_APP" list
chmod 0700 "$unsafe_children_data/fedora-web-apps"
chmod 0770 "$unsafe_children_data/applications"
expect_failure env HOME="$unsafe_children_home" XDG_DATA_HOME="$unsafe_children_data" "$WEB_APP" add \
    --id unsafe-applications --name 'Unsafe Applications' --url https://example.com/

foreign_data="$TEMP_DIR/foreign metadata data"
foreign_home="$TEMP_DIR/foreign metadata home"
foreign_bin="$TEMP_DIR/foreign metadata bin"
mkdir -p "$foreign_data" "$foreign_home" "$foreign_bin"
env HOME="$foreign_home" XDG_DATA_HOME="$foreign_data" "$WEB_APP" add \
    --id foreign --name Foreign --url https://example.com/ >/dev/null
foreign_metadata="$foreign_data/fedora-web-apps/fedora-web-app-foreign.tsv"
printf '%s\n' '#!/usr/bin/env bash' \
    'if [[ "$1" == "-c" && "$2" == "%u" && "${@: -1}" == "$WEB_APP_TEST_FOREIGN_METADATA" ]]; then printf "424242\n"; else exec /usr/bin/stat "$@"; fi' \
    > "$foreign_bin/stat"
chmod +x "$foreign_bin/stat"
expect_failure env HOME="$foreign_home" XDG_DATA_HOME="$foreign_data" \
    WEB_APP_TEST_FOREIGN_METADATA="$foreign_metadata" PATH="$foreign_bin:/usr/bin:/bin" \
    "$WEB_APP" list
expect_failure env HOME="$foreign_home" XDG_DATA_HOME="$foreign_data" \
    WEB_APP_TEST_FOREIGN_METADATA="$foreign_metadata" PATH="$foreign_bin:/usr/bin:/bin" \
    "$WEB_APP" launch --id foreign

race_data="$TEMP_DIR/race data"
race_home="$TEMP_DIR/race home"
race_external="$TEMP_DIR/race external"
race_bin="$TEMP_DIR/race bin"
mkdir -p "$race_data" "$race_home" "$race_external" "$race_bin"
printf '%s\n' '#!/usr/bin/env bash' \
    'count_file="$WEB_APP_TEST_RACE_ROOT/.fedora-web-app-test-cat-count"' \
    'count=0' \
    '[[ -f "$count_file" ]] && read -r count < "$count_file"' \
    'count=$((count + 1))' \
    'printf "%s\\n" "$count" > "$count_file"' \
    '/usr/bin/cat "$@"' \
    'status=$?' \
    'if [[ "$count" -eq 2 ]]; then' \
    '    touch "$WEB_APP_TEST_RACE_ROOT/.fedora-web-app-test-ready"' \
    '    while [[ ! -e "$WEB_APP_TEST_RACE_ROOT/.fedora-web-app-test-proceed" ]]; do sleep 0.01; done' \
    'fi' \
    'exit "$status"' > "$race_bin/cat"
chmod +x "$race_bin/cat"
race_metadata="$race_data/fedora-web-apps/fedora-web-app-race.tsv"
env HOME="$race_home" XDG_DATA_HOME="$race_data" \
    WEB_APP_TEST_RACE_ROOT="$race_data" PATH="$race_bin:/usr/bin:/bin" "$WEB_APP" add \
    --id race --name Race --url https://example.com/ >/dev/null 2>&1 &
race_pid=$!
race_ready="$race_data/.fedora-web-app-test-ready"
for _ in {1..100}; do
    [[ -e "$race_ready" ]] && break
    sleep 0.01
done
[[ -e "$race_ready" ]] || fail "Race hook did not reach post-write barrier."
mv -- "$race_data/fedora-web-apps" "$race_data/fedora-web-apps-held"
ln -s -- "$race_external" "$race_data/fedora-web-apps"
touch "$race_data/.fedora-web-app-test-proceed"
if wait "$race_pid"; then
    fail "Directory-swap race unexpectedly succeeded."
fi
[[ -z "$(find "$race_external" -mindepth 1 -print -quit)" ]] || \
    fail "Directory-swap race wrote to the external target."
[[ -z "$(find "$race_data" -name '.fedora-web-app-race.tsv.*' -print -quit)" ]] || \
    fail "Directory-swap race left temporary metadata residue."

list_output="$(env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" list)"
[[ "$list_output" == *$'outlook\tOutlook\thttps://outlook.cloud.microsoft/mail/'* ]] || fail "List output mismatch."
env HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_DATA" "$WEB_APP" remove --id outlook
[[ ! -e "$desktop_file" && ! -e "$config_file" ]] || fail "Remove did not delete managed files."

printf 'webapps: all tests passed\n'
