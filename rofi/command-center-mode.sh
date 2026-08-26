#!/usr/bin/env bash
set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
command_center="$config_home/rofi/command-center.sh"

entries=(
    "System › Control Center"
    "System › Audio"
    "System › Network"
    "System › Bluetooth"
    "System › System Activity"
    "System › Clipboard History"
    "System › Toggle Caffeine"
    "System › Toggle Do Not Disturb"
    "Capture › Region Screenshot"
    "Capture › Focused Window Screenshot"
    "Capture › Focused Output Screenshot"
    "Capture › All Outputs Screenshot"
    "Capture › Annotate Region"
    "Capture › Screen Recorder"
    "Capture › Color Picker"
    "Capture › OCR Region to Clipboard"
    "Capture › Open Screenshots Folder"
    "Appearance › Themes"
    "Appearance › Wallpapers"
    "Appearance › Toggle Light/Dark Mode"
    "Appearance › Noctalia Settings"
    "Tools › Terminal"
    "Tools › System Monitor (btop)"
    "Tools › File Manager"
    "Tools › Edit Niri Config"
    "Tools › Edit Noctalia Config"
    "Tools › Fedora Updates"
    "Power › Lock"
    "Power › Suspend"
    "Power › Log Out"
    "Power › Restart"
    "Power › Shut Down"
)

if [[ "${ROFI_RETV:-0}" == "0" ]]; then
    printf '\0no-custom\x1ftrue\n'
    for entry in "${entries[@]}"; do
        case "$entry" in
            "System › Audio") icon="audio-volume-high" ;;
            "System › Network") icon="network-wireless" ;;
            "System › Bluetooth") icon="bluetooth" ;;
            "System › Clipboard History") icon="edit-paste" ;;
            "System › Toggle Caffeine") icon="caffeine-cup-empty" ;;
            "System › Toggle Do Not Disturb") icon="notifications-disabled" ;;
            "System ›"*) icon="utilities-system-monitor" ;;
            "Capture › OCR"*) icon="edit-select-text" ;;
            "Capture › Color"*) icon="color-picker" ;;
            "Capture › Open"*) icon="folder-pictures" ;;
            "Capture › Screen Recorder") icon="media-record" ;;
            "Capture ›"*) icon="camera-photo" ;;
            "Appearance › Themes") icon="preferences-desktop-theme" ;;
            "Appearance › Wallpapers") icon="preferences-desktop-wallpaper" ;;
            "Appearance › Toggle"*) icon="weather-clear-night" ;;
            "Appearance ›"*) icon="preferences-system" ;;
            "Tools › Terminal") icon="utilities-terminal" ;;
            "Tools › System Monitor"*) icon="utilities-system-monitor" ;;
            "Tools › File Manager") icon="system-file-manager" ;;
            "Tools › Fedora Updates") icon="system-software-update" ;;
            "Tools ›"*) icon="text-editor" ;;
            "Power › Lock") icon="system-lock-screen" ;;
            "Power › Suspend") icon="system-suspend" ;;
            "Power › Log Out") icon="system-log-out" ;;
            "Power › Restart") icon="system-reboot" ;;
            "Power › Shut Down") icon="system-shutdown" ;;
            *) icon="application-x-executable" ;;
        esac
        printf '%s\0icon\x1f%s\n' "$entry" "$icon"
    done
    exit 0
fi

selection="${1:-}"
if [[ -z "$selection" ]]; then
    exit 0
fi

# Rofi waits for script providers; detach the selected action so the unified
# launcher can close before a submenu or another layer-shell surface opens.
coproc COMMAND_CENTER_ACTION {
    sleep 0.1
    "$command_center" "$selection" >/dev/null 2>&1
}
