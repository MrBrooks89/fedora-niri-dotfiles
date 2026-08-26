#!/usr/bin/env bash
set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
command_mode="$config_home/rofi/command-center-mode.sh"
category_mode="$config_home/rofi/command-center-categories-mode.sh"

exec rofi \
    -show combi \
    -modes "combi,categories:$category_mode,drun,actions:$command_mode" \
    -combi-modes "categories,drun,actions" \
    -display-combi "Search" \
    -display-categories "Menu" \
    -display-drun "App" \
    -display-actions "Command" \
    -kb-mode-next "" \
    -kb-mode-previous "" \
    -kb-row-left "" \
    -kb-row-right "" \
    -kb-move-char-back "Control+b" \
    -kb-move-char-forward "Control+f" \
    -kb-move-word-back "Alt+b" \
    -kb-move-word-forward "Alt+f" \
    -combi-display-format "{text}"
