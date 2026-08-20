#!/usr/bin/env bash

# Default: select area with slurp
grim -g "$(slurp)" - | satty --no-window-decoration -f -
