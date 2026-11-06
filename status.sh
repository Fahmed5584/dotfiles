#!/usr/bin/env bash
# Show battery % (with a bar), time and date as a Hyprland notification.
 
bat=$(cat /sys/class/power_supply/BAT*/capacity | head -n1)
now=$(date '+%-I:%M %^p')
today=$(date '+%d/%m/%Y')
 
# 10-block bar, one block per 10% (rounded)
for i in {1..10}; do (( i <= (bat + 5) / 10 )) && bar+="█" || bar+="░"; done
 
# icon 1 = info, 5000 ms, colour 0 = default colour for the icon
hyprctl notify 2 3000 0 "Battery ${bar} ${bat}%  ·  ${now}  ·  ${today}"
