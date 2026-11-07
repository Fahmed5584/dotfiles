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

# 3. Fuzzel:
mkdir -p "$HOME/.config/fuzzel"
cp "$repo_dir/fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"
echo "Copied fuzzel/fuzzel.ini to ~/.config/fuzzel/"

# 4. Glow:
mkdir -p "$HOME/.config/glow"
cp "$repo_dir/glow/glow.yml" "$HOME/.config/glow/glow.yml"
echo "Copied glow/glow.yml to ~/.config/glow/"

# 5. Mako:
mkdir -p "$HOME/.config/mako"
cp "$repo_dir/mako/config" "$HOME/.config/mako/config"
echo "Copied mako/config to ~/.config/mako/"

# 6. keepassxc
mkdir -p "$HOME/.config/keepassxc"
cp "$repo_dir/keepassxc/keepassxc.ini" "$HOME/.config/keepassxc/keepassxc.ini"
echo "Copied keepassxc/keepassxc.ini to ~/.config/keepassxc/"

# 7. Qutebrowser
mkdir -p "$HOME/.config/qutebrowser"
cp -r "$repo_dir/qutebrowser/." "$HOME/.config/qutebrowser/"
echo "Copied qutebrowser/ to ~/.config/qutebrowser/"

# 8. Kitty
mkdir -p "$HOME/.config/kitty"
cp "$repo_dir/kitty/kitty.conf" "$HOME/.config/kitty/"
echo "Copied kitty/kitty.conf" to ~/.config/kitty/"

# 9. Waybar
mkdir -p "$HOME/.config/waybar"
cp -r "$repo_dir/waybar/." "$HOME/.config/waybar/"
echo "Copied waybar/ to ~/.config/waybar/"

# 10. Copy status script
cp "$repo_dir/status.sh" "$HOME/status.sh"
echo "Copied status.sh to ~/status.sh"
