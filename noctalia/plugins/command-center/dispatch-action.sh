#!/usr/bin/env bash
set -u

capture_tools="$HOME/.config/noctalia/plugins/command-center/capture-tools.sh"
reminder="$HOME/.local/bin/fedora-reminder"
web_app="$HOME/.local/bin/fedora-web-app"

launch_localsend() {
    if ! command -v flatpak >/dev/null 2>&1 || ! flatpak info org.localsend.localsend_app >/dev/null 2>&1; then
        notify-send --app-name="LocalSend" --urgency=normal \
            "LocalSend is not installed" \
            "Install it with bootstrap-fedora44-niri-v3.sh --with-localsend, then choose Sharing again."
        return 0
    fi

    flatpak run org.localsend.localsend_app
}

launch_outlook_web_app() {
    if [[ ! -x "$web_app" ]]; then
        notify-send --app-name="Web Apps" --urgency=normal \
            "Web app manager is unavailable" \
            "Run the Fedora bootstrap to install the managed Outlook launcher."
        return 0
    fi

    "$web_app" launch --id outlook
}

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
    "Sharing › Open LocalSend") launch_localsend ;;
    "Sharing › Open Outlook Web App") launch_outlook_web_app ;;
    "Tools › Reminder in 5 Minutes") "$reminder" add 5m "Five-minute reminder" ;;
    "Tools › Reminder in 15 Minutes") "$reminder" add 15m "Fifteen-minute reminder" ;;
    "Tools › Reminder in 30 Minutes") "$reminder" add 30m "Thirty-minute reminder" ;;
    "Tools › List Reminders") kitty --hold --title "Active Reminders" "$reminder" list ;;
    "Tools › Clear Reminders") "$reminder" clear ;;
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
