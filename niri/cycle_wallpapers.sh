#!/usr/bin/env bash

# Initiate SWW
#swww init

# Set the duration for each image (in seconds)
DURATION=300

# Specify the full path to your Pictures directory
PICTURES_DIR="/home/mrbrooks/Pictures"

# Loop indefinitely
while true; do
  # Use find to get all image files and pick one randomly
  img=$(find "$PICTURES_DIR" -type f \( -name '*.jpg' -o -name '*.png' \) | shuf -n 1)

  # Check if an image was found
  if [ -e "$img" ]; then
    swww img "$img" # Set the wallpaper
    sleep $DURATION # Wait for the specified duration
  fi
done
