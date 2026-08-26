#!/usr/bin/env bash
set -euo pipefail

screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$screenshot_dir"

notify() {
    notify-send --app-name="Capture Tools" "$1" "${2:-}"
}

new_path() {
    printf '%s/Screenshot %(%Y-%m-%d %H-%M-%S)T.png' "$screenshot_dir" -1
}

capture_image() {
    local source="$1"
    local output="$2"
    local geometry

    case "$source" in
        region)
            geometry=$(slurp -d) || return 1
            grim -g "$geometry" "$output"
            ;;
        window)
            niri msg action screenshot-window --write-to-disk true --path "$output" >/dev/null
            ;;
        output)
            niri msg action screenshot-screen --write-to-disk true --show-pointer false --path "$output" >/dev/null
            ;;
        all)
            grim "$output"
            ;;
        *)
            notify "Capture failed" "Unknown source: $source"
            return 1
            ;;
    esac
}

finish_screenshot() {
    local image="$1"
    local action="${2:-save}"
    local destination

    case "$action" in
        copy)
            wl-copy --type image/png <"$image"
            notify "Screenshot copied" "The image is ready to paste."
            ;;
        save)
            destination=$(new_path)
            install -m 0644 "$image" "$destination"
            notify "Screenshot saved" "$destination"
            ;;
        annotate)
            destination=$(new_path)
            satty \
                --filename "$image" \
                --output-filename "$destination" \
                --copy-command wl-copy \
                --no-window-decoration \
                --floating-hack
            ;;
        open)
            destination=$(new_path)
            install -m 0644 "$image" "$destination"
            xdg-open "$destination" >/dev/null 2>&1 &
            ;;
        *)
            notify "Capture failed" "Unknown result action: $action"
            return 1
            ;;
    esac
}

screenshot() {
    local source="$1"
    local action="${2:-save}"
    local image
    image=$(mktemp --suffix=.png)

    if ! capture_image "$source" "$image"; then
        rm -f "$image"
        return
    fi
    finish_screenshot "$image" "$action"
    rm -f "$image"
}

pick_color() {
    local geometry red green blue hex
    geometry=$(slurp -p -f '%x,%y 1x1') || return
    read -r red green blue < <(grim -g "$geometry" -t ppm - | tail -c 3 | od -An -tu1)
    printf -v hex '#%02X%02X%02X' "$red" "$green" "$blue"
    printf '%s' "$hex" | wl-copy
    notify "Color copied" "$hex"
}

ocr_region() {
    local image text
    if ! command -v tesseract >/dev/null 2>&1; then
        notify "OCR unavailable" "Install it with: sudo dnf install tesseract"
        return 1
    fi

    image=$(mktemp --suffix=.png)
    if ! capture_image region "$image"; then
        rm -f "$image"
        return
    fi
    text=$(tesseract "$image" stdout -l eng 2>/dev/null)
    rm -f "$image"

    if [[ -z "$text" ]]; then
        notify "No text found" "Try selecting a clearer or larger region."
        return
    fi

    printf '%s' "$text" | wl-copy
    notify "Text copied" "OCR result is ready to paste."
}

case "${1:-}" in
    screenshot) screenshot "${2:-region}" "${3:-save}" ;;
    color) pick_color ;;
    ocr) ocr_region ;;
    open-folder) xdg-open "$screenshot_dir" >/dev/null 2>&1 & ;;
    *)
        printf 'Usage: %s {screenshot {region|window|output|all} [copy|save|annotate|open]|color|ocr|open-folder}\n' "$0" >&2
        exit 2
        ;;
esac
