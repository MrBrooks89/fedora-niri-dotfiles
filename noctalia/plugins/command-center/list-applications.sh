#!/usr/bin/env bash
set -euo pipefail

# Emit visible desktop entries as tab-separated id, name, comment, icon and path.
# Earlier XDG directories win when the same desktop id appears more than once.
declare -A seen=()
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
search_dirs=("$data_home/applications")

IFS=: read -r -a system_data_dirs <<< "$data_dirs"
for directory in "${system_data_dirs[@]}"; do
    search_dirs+=("$directory/applications")
done

while IFS= read -r -d '' desktop_file; do
    desktop_id="${desktop_file##*/}"
    [[ -n "${seen[$desktop_id]:-}" ]] && continue
    seen[$desktop_id]=1

    entry_type=""
    name=""
    comment=""
    icon=""
    hidden="false"
    no_display="false"
    in_entry=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        if [[ "$line" == "[Desktop Entry]" ]]; then
            in_entry=true
            continue
        fi
        if [[ "$line" == \[*\] ]]; then
            $in_entry && break
            continue
        fi
        $in_entry || continue

        case "$line" in
            Type=*) entry_type="${line#Type=}" ;;
            Name=*) [[ -z "$name" ]] && name="${line#Name=}" ;;
            Comment=*) [[ -z "$comment" ]] && comment="${line#Comment=}" ;;
            Icon=*) [[ -z "$icon" ]] && icon="${line#Icon=}" ;;
            Hidden=*) hidden="${line#Hidden=}" ;;
            NoDisplay=*) no_display="${line#NoDisplay=}" ;;
        esac
    done < "$desktop_file"

    [[ "$entry_type" == "Application" && -n "$name" ]] || continue
    [[ "${hidden,,}" != "true" && "${no_display,,}" != "true" ]] || continue

    name="${name//$'\t'/ }"
    comment="${comment//$'\t'/ }"
    icon="${icon//$'\t'/ }"
    printf '%s\t%s\t%s\t%s\t%s\n' "$desktop_id" "$name" "$comment" "$icon" "$desktop_file"
done < <(
    for directory in "${search_dirs[@]}"; do
        [[ -d "$directory" ]] && find "$directory" -maxdepth 1 -type f -name '*.desktop' -print0
    done
) | sort -t $'\t' -k2,2f

