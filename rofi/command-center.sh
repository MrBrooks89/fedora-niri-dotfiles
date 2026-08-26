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
        "Screenshot Region" \
        "Screenshot Focused Display" \
        "Screenshot All Displays" \
        "Screen Recorder") || return

    case "$choice" in
        "Screenshot Region") noctalia msg screenshot-region ;;
        "Screenshot Focused Display") noctalia msg screenshot-fullscreen ;;
        "Screenshot All Displays") noctalia msg screenshot-fullscreen all ;;
        "Screen Recorder") noctalia msg plugin noctalia/screen_recorder:service all toggle ;;
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
    "Power") || exit 0

case "$choice" in
    "Applications") rofi -show drun ;;
    "System") system_menu ;;
    "Capture") capture_menu ;;
    "Appearance") appearance_menu ;;
    "Tools") tools_menu ;;
    "Power") power_menu ;;
esac
