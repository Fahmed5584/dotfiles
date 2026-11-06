#!/usr/bin/env bash
# Post-install setup. Run as your normal user at the TTY after the first boot.
# Installs every package, sets up the firewall, dotfiles, Syncthing and key-only SSH.
# Safe to run again. Usage: bash arch-setup.sh
set -euo pipefail
trap 'echo "FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR

# 1. Checks
[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root."; exit 1; }
ping -c 1 -W 5 archlinux.org >/dev/null || { echo "No internet. Connect with: iwctl station wlan0 connect \"<network name>\""; exit 1; }

# 2. Update. If the kernel changed, its modules (which ufw needs) won't load until a reboot
sudo pacman -Syu --noconfirm
if [[ ! -d /usr/lib/modules/$(uname -r) ]]; then
  echo "The kernel was updated. Reboot, then run this script again."
  exit 0
fi

# 3. Packages
sudo pacman -S --needed --noconfirm \
  brightnessctl pipewire wireplumber pipewire-pulse less man-db rsync \
  ufw openssh \
  hyprland kitty wl-clipboard ttf-dejavu ttf-jetbrains-mono \
  ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common \
  vulkan-intel intel-media-driver \
  git github-cli fzf ripgrep fd \
  qutebrowser keepassxc qt6-wayland syncthing fuzzel mako

# 4. Firewall: deny incoming except SSH and Syncthing from the home network
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.50.0/24 to any port 22 proto tcp
sudo ufw allow from 192.168.50.0/24 to any port 22000 proto tcp
sudo ufw allow from 192.168.50.0/24 to any port 22000 proto udp
sudo ufw allow from 192.168.50.0/24 to any port 21027 proto udp
sudo ufw --force enable
sudo systemctl enable --now ufw

# 5. Dotfiles (Hyprland and Neovim configs)
if [[ -d ~/dotfiles ]]; then
  git -C ~/dotfiles pull
else
  git clone https://github.com/Fahmed5584/dotfiles ~/dotfiles
fi
bash ~/dotfiles/xps-dotfile-install.sh

# 6. Syncthing, started at every login
systemctl --user enable --now syncthing.service

# 7. SSH, keys only. Safe to start now: with passwords off and no key added, nobody can log in yet
install -d -m 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
sudo tee /etc/ssh/sshd_config.d/10-hardening.conf >/dev/null <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers $USER
EOF
sudo ssh-keygen -A
sudo sshd -t
sudo systemctl enable --now sshd

echo
echo "Setup done. Still to do by hand:"
echo "  1. start-hyprland"
echo "  2. Open http://127.0.0.1:8384 in qutebrowser and pair your Syncthing devices"
echo "  3. Paste your public key from KeePassXC into ~/.ssh/authorized_keys"
echo "  4. From another computer: ssh $USER@$(ip -4 -brief addr show wlan0 2>/dev/null | awk '{print $3}' | cut -d/ -f1)"
