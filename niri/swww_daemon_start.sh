#!/usr/bin/env bash

swww-daemon &
"${XDG_CONFIG_HOME:-$HOME/.config}/niri/cycle_wallpapers.sh"
