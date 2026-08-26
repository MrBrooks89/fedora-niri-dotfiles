#!/usr/bin/env bash
set -u

capture_tools="$HOME/.config/noctalia/plugins/command-center/capture-tools.sh"

case "${1:-}" in
    "System › Control Center") noctalia msg panel-toggle control-center ;;
    "System › Audio") noctalia msg panel-toggle control-center audio ;;
    "System › Network") noctalia msg panel-toggle control-center network ;;
    "System › Bluetooth") noctalia msg panel-toggle control-center bluetooth ;;
    "System › System Activity") noctalia msg panel-toggle control-center system ;;
    "System › Clipboard History") noctalia msg panel-toggle clipboard ;;
    "System › Toggle Caffeine") noctalia msg caffeine-toggle ;;
    "System › Toggle Do Not Disturb") noctalia msg notification-dnd-toggle ;;
    "Capture › Region Screenshot") "$capture_tools" screenshot region ;;
    "Capture › Focused Window Screenshot") "$capture_tools" screenshot window ;;
    "Capture › Focused Output Screenshot") "$capture_tools" screenshot output ;;
    "Capture › All Outputs Screenshot") "$capture_tools" screenshot all ;;
    "Capture › Annotate Region") "$capture_tools" screenshot region annotate ;;
    "Capture › Screen Recorder") noctalia msg plugin noctalia/screen_recorder:service all toggle ;;
    "Capture › Color Picker") "$capture_tools" color ;;
    "Capture › OCR Region to Clipboard") "$capture_tools" ocr ;;
    "Capture › Open Screenshots Folder") "$capture_tools" open-folder ;;
    "Appearance › Themes") noctalia msg settings-open theme ;;
    "Appearance › Wallpapers") noctalia msg panel-toggle wallpaper ;;
    "Appearance › Toggle Light/Dark Mode") noctalia msg theme-mode-toggle ;;
    "Appearance › Noctalia Settings") noctalia msg settings-open ;;
    "Tools › Terminal") kitty ;;
    "Tools › System Monitor (btop)") kitty --class btop btop ;;
    "Tools › File Manager") dolphin ;;
    "Tools › Edit Niri Config") kitty nvim "$HOME/.config/niri/config.kdl" ;;
    "Tools › Edit Noctalia Config") kitty nvim "$HOME/.config/noctalia/config.toml" ;;
    "Tools › Fedora Updates") kitty --hold --title "Fedora Updates" sudo dnf upgrade --refresh ;;
    "Power › Lock") noctalia msg session lock ;;
    "Power › Suspend") noctalia msg session suspend ;;
    "Power › Log Out") noctalia msg session logout ;;
    "Power › Restart") noctalia msg session reboot ;;
    "Power › Shut Down") noctalia msg session shutdown ;;
    *)
        printf 'Unknown command-center action: %s\n' "${1:-<empty>}" >&2
        exit 2
        ;;
esac
