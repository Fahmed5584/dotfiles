#!/usr/bin/env bash

# Set your wallpaper folder path
WALLPAPER_DIR="$HOME/wallpapers"

# Pick one random image file from the directory
RANDOM_WALLPAPER=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) | shuf -n 1)

# Exit safely if no images are found
if [ -z "$RANDOM_WALLPAPER" ]; then
    echo "No images found in $WALLPAPER_DIR"
    exit 1
fi

# Run matugen detached from the terminal so closing the terminal won't kill swaybg
#nohup matugen image "$RANDOM_WALLPAPER" --mode dark --type scheme-content --prefer less-saturation >/dev/null 2>&1 &

#nohup matugen image "$RANDOM_WALLPAPER" --mode dark --source-color-index 0 --type scheme-content >/dev/null 2>&1 &

#A
nohup matugen image "$RANDOM_WALLPAPER" --mode dark --prefer saturation --type scheme-rainbow >/dev/null 2>&1 &

#B
#nohup matugen image "$RANDOM_WALLPAPER" --mode dark --source-color-index 0 --type scheme-expressive >/dev/null 2>&1 &

#C
#nohup matugen image "$RANDOM_WALLPAPER" --mode dark --prefer less-saturation --type scheme-fruit-salad >/dev/null 2>&1 &


