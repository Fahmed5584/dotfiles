#!bin/bash
# Overwrites files with the same name; leaves any other files there alone.
# Usage: bash install.sh   (from anywhere; paths are relative to this script)
set -euo pipefail
 
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 
# 1. Hyprland: everything in hyprland/, including hidden files
mkdir -p "$HOME/.config/hypr"
cp -r "$repo_dir/hyprland/." "$HOME/.config/hypr/"
echo "Copied hyprland/ to ~/.config/hypr/"
 
# 2. Neovim: init.lua only
mkdir -p "$HOME/.config/nvim"
cp "$repo_dir/nvim/init.lua" "$HOME/.config/nvim/init.lua"
echo "Copied nvim/init.lua to ~/.config/nvim/"
