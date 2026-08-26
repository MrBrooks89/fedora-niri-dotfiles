#!/usr/bin/env bash
set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
command_center="$config_home/rofi/command-center.sh"

entries=(
    "Applications|applications-other"
    "System|preferences-system"
    "Capture|camera-photo"
    "Appearance|preferences-desktop-theme"
    "Tools|applications-utilities"
    "Power|system-shutdown"
)

if [[ "${ROFI_RETV:-0}" == "0" ]]; then
    printf '\0no-custom\x1ftrue\n'
    for item in "${entries[@]}"; do
        label="${item%%|*}"
        icon="${item#*|}"
        printf '%s\0icon\x1f%s\n' "$label" "$icon"
    done
    exit 0
fi

selection="${1:-}"
if [[ -z "$selection" ]]; then
    exit 0
fi

coproc COMMAND_CENTER_CATEGORY {
    sleep 0.1
    "$command_center" "$selection" >/dev/null 2>&1
}
