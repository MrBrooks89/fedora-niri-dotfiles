#!/usr/bin/env bash
set -u

menu() {
    local prompt="$1"
    shift
    printf '%s\n' "$@" | rofi -dmenu -i -no-custom -p "$prompt"
}

system_menu() {
    local choice
    choice=$(menu "System" \
        "Control Center" \
        "Audio" \
        "Network" \
        "Bluetooth" \
        "System Activity" \
        "Clipboard History" \
        "Toggle Caffeine" \
        "Toggle Do Not Disturb") || return

    case "$choice" in
        "Control Center") noctalia msg panel-toggle control-center ;;
        "Audio") noctalia msg panel-toggle control-center audio ;;
        "Network") noctalia msg panel-toggle control-center network ;;
        "Bluetooth") noctalia msg panel-toggle control-center bluetooth ;;
        "System Activity") noctalia msg panel-toggle control-center system ;;
        "Clipboard History") noctalia msg panel-toggle clipboard ;;
        "Toggle Caffeine") noctalia msg caffeine-toggle ;;
        "Toggle Do Not Disturb") noctalia msg notification-dnd-toggle ;;
    esac
}

capture_menu() {
    local choice
    choice=$(menu "Capture" \
        "Region Screenshot" \
        "Focused Window Screenshot" \
        "Focused Output Screenshot" \
        "All Outputs Screenshot" \
        "Annotate Region" \
        "Screen Recorder" \
        "Color Picker" \
        "OCR Region to Clipboard" \
        "Open Screenshots Folder") || return

    case "$choice" in
        "Region Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot region ;;
        "Focused Window Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot window ;;
        "Focused Output Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot output ;;
        "All Outputs Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot all ;;
        "Annotate Region") "$HOME/.config/rofi/capture-tools.sh" screenshot region annotate ;;
        "Screen Recorder") noctalia msg plugin noctalia/screen_recorder:service all toggle ;;
        "Color Picker") "$HOME/.config/rofi/capture-tools.sh" color ;;
        "OCR Region to Clipboard") "$HOME/.config/rofi/capture-tools.sh" ocr ;;
        "Open Screenshots Folder") "$HOME/.config/rofi/capture-tools.sh" open-folder ;;
    esac
}

appearance_menu() {
    local choice
    choice=$(menu "Appearance" \
        "Themes" \
        "Wallpapers" \
        "Toggle Light/Dark Mode" \
        "Noctalia Settings") || return

    case "$choice" in
        "Themes") noctalia msg settings-open theme ;;
        "Wallpapers") noctalia msg panel-toggle wallpaper ;;
        "Toggle Light/Dark Mode") noctalia msg theme-mode-toggle ;;
        "Noctalia Settings") noctalia msg settings-open ;;
    esac
}

tools_menu() {
    local choice
    choice=$(menu "Tools" \
        "Terminal" \
        "System Monitor (btop)" \
        "File Manager" \
        "Edit Niri Config" \
        "Edit Noctalia Config" \
        "Fedora Updates") || return

    case "$choice" in
        "Terminal") kitty ;;
        "System Monitor (btop)") kitty --class btop btop ;;
        "File Manager") dolphin ;;
        "Edit Niri Config") kitty nvim "$HOME/.config/niri/config.kdl" ;;
        "Edit Noctalia Config") kitty nvim "$HOME/.config/noctalia/config.toml" ;;
        "Fedora Updates") kitty --title "Fedora Updates" sudo dnf upgrade --refresh ;;
    esac
}

power_menu() {
    local choice
    choice=$(menu "Power" \
        "Lock" \
        "Suspend" \
        "Log Out" \
        "Restart" \
        "Shut Down") || return

    case "$choice" in
        "Lock") noctalia msg session lock ;;
        "Suspend") noctalia msg session suspend ;;
        "Log Out") noctalia msg session logout ;;
        "Restart") noctalia msg session reboot ;;
        "Shut Down") noctalia msg session shutdown ;;
    esac
}

choice=$(menu "Command Center" \
    "Applications" \
    "System" \
    "Capture" \
    "Appearance" \
    "Tools" \
    "Power" \
    "System › Control Center" \
    "System › Audio" \
    "System › Network" \
    "System › Bluetooth" \
    "System › System Activity" \
    "System › Clipboard History" \
    "System › Toggle Caffeine" \
    "System › Toggle Do Not Disturb" \
    "Capture › Region Screenshot" \
    "Capture › Focused Window Screenshot" \
    "Capture › Focused Output Screenshot" \
    "Capture › All Outputs Screenshot" \
    "Capture › Annotate Region" \
    "Capture › Screen Recorder" \
    "Capture › Color Picker" \
    "Capture › OCR Region to Clipboard" \
    "Capture › Open Screenshots Folder" \
    "Appearance › Themes" \
    "Appearance › Wallpapers" \
    "Appearance › Toggle Light/Dark Mode" \
    "Appearance › Noctalia Settings" \
    "Tools › Terminal" \
    "Tools › System Monitor (btop)" \
    "Tools › File Manager" \
    "Tools › Edit Niri Config" \
    "Tools › Edit Noctalia Config" \
    "Tools › Fedora Updates" \
    "Power › Lock" \
    "Power › Suspend" \
    "Power › Log Out" \
    "Power › Restart" \
    "Power › Shut Down") || exit 0

case "$choice" in
    "Applications") rofi -show drun ;;
    "System") system_menu ;;
    "Capture") capture_menu ;;
    "Appearance") appearance_menu ;;
    "Tools") tools_menu ;;
    "Power") power_menu ;;
    "System › Control Center") noctalia msg panel-toggle control-center ;;
    "System › Audio") noctalia msg panel-toggle control-center audio ;;
    "System › Network") noctalia msg panel-toggle control-center network ;;
    "System › Bluetooth") noctalia msg panel-toggle control-center bluetooth ;;
    "System › System Activity") noctalia msg panel-toggle control-center system ;;
    "System › Clipboard History") noctalia msg panel-toggle clipboard ;;
    "System › Toggle Caffeine") noctalia msg caffeine-toggle ;;
    "System › Toggle Do Not Disturb") noctalia msg notification-dnd-toggle ;;
    "Capture › Region Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot region ;;
    "Capture › Focused Window Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot window ;;
    "Capture › Focused Output Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot output ;;
    "Capture › All Outputs Screenshot") "$HOME/.config/rofi/capture-tools.sh" screenshot all ;;
    "Capture › Annotate Region") "$HOME/.config/rofi/capture-tools.sh" screenshot region annotate ;;
    "Capture › Screen Recorder") noctalia msg plugin noctalia/screen_recorder:service all toggle ;;
    "Capture › Color Picker") "$HOME/.config/rofi/capture-tools.sh" color ;;
    "Capture › OCR Region to Clipboard") "$HOME/.config/rofi/capture-tools.sh" ocr ;;
    "Capture › Open Screenshots Folder") "$HOME/.config/rofi/capture-tools.sh" open-folder ;;
    "Appearance › Themes") noctalia msg settings-open theme ;;
    "Appearance › Wallpapers") noctalia msg panel-toggle wallpaper ;;
    "Appearance › Toggle Light/Dark Mode") noctalia msg theme-mode-toggle ;;
    "Appearance › Noctalia Settings") noctalia msg settings-open ;;
    "Tools › Terminal") kitty ;;
    "Tools › System Monitor (btop)") kitty --class btop btop ;;
    "Tools › File Manager") dolphin ;;
    "Tools › Edit Niri Config") kitty nvim "$HOME/.config/niri/config.kdl" ;;
    "Tools › Edit Noctalia Config") kitty nvim "$HOME/.config/noctalia/config.toml" ;;
    "Tools › Fedora Updates") kitty --title "Fedora Updates" sudo dnf upgrade --refresh ;;
    "Power › Lock") noctalia msg session lock ;;
    "Power › Suspend") noctalia msg session suspend ;;
    "Power › Log Out") noctalia msg session logout ;;
    "Power › Restart") noctalia msg session reboot ;;
    "Power › Shut Down") noctalia msg session shutdown ;;
esac
