#!/usr/bin/env bash
# Arch Linux install for the XPS 13. Run from the Arch live USB, as root, once you're online.
# Wipes the chosen disk, installs minimal Arch with the CachyOS kernel and systemd-boot,
# and copies the live USB's saved Wi-Fi onto the new system so the first boot is online.
# Usage: bash arch-install.sh
set -euo pipefail
trap 'echo "FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR

# Prompts for a password twice and prints it; prompts go to stderr so $(...) captures only the password
ask_password() {
  local first second
  while true; do
    read -rsp "$1: " first; echo >&2
    read -rsp "$1 (again): " second; echo >&2
    [[ -n $first && $first == "$second" ]] && break
    echo "Empty or didn't match, try again." >&2
  done
  printf '%s' "$first"
}

# 1. Checks
[[ $EUID -eq 0 ]] || { echo "Run as root from the live USB."; exit 1; }
[[ $(cat /sys/firmware/efi/fw_platform_size 2>/dev/null) == 64 ]] || { echo "Not booted in 64-bit UEFI mode."; exit 1; }
ping -c 1 -W 5 archlinux.org >/dev/null || { echo "No internet. Connect with iwctl first."; exit 1; }

# 2. Questions (everything after this runs without stopping)
lsblk -d -o NAME,SIZE,MODEL,TRAN
read -rp "Disk to install on [sda]: " disk
disk="${disk:-sda}"
disk="/dev/${disk#/dev/}"
[[ -b $disk ]] || { echo "$disk is not a disk."; exit 1; }
if lsblk -no MOUNTPOINTS "$disk" | grep -q .; then
  echo "$disk has mounted partitions. Is it the USB stick?"; exit 1
fi

read -rp "Computer name: " host
while true; do
  read -rp "Username (lowercase, no spaces): " user
  [[ $user =~ ^[a-z_][a-z0-9_-]*$ ]] && break
done
root_pw=$(ask_password "Root password")
user_pw=$(ask_password "Password for $user")

echo
lsblk "$disk"
read -rp "Type $(basename "$disk") to ERASE it and install: " confirm
[[ $confirm == "$(basename "$disk")" ]] || { echo "Cancelled."; exit 1; }

# Log everything from here on (passwords are never printed)
exec > >(tee /tmp/arch-install.log) 2>&1

# 3. Partition, format, mount: 1 GiB EFI boot partition, rest ext4 root
timedatectl set-ntp true
if [[ $disk =~ [0-9]$ ]]; then part="${disk}p"; else part="$disk"; fi   # nvme0n1 -> nvme0n1p1, sda -> sda1
boot_part="${part}1"
root_part="${part}2"

sfdisk --wipe always --wipe-partitions always "$disk" <<'EOF'
label: gpt
,1GiB,U
,,L
EOF
udevadm settle

mkfs.fat -F 32 "$boot_part"
mkfs.ext4 -F "$root_part"
mount "$root_part" /mnt
mount --mkdir "$boot_part" /mnt/boot

# 4. Base system
pacstrap -K /mnt base linux-firmware intel-ucode sudo neovim iwd
genfstab -U /mnt >> /mnt/etc/fstab

# 5. Wi-Fi: reuse the network you joined on the live USB, and the systemd-networkd config
install -d -m 700 /mnt/var/lib/iwd
cp /var/lib/iwd/*.psk /mnt/var/lib/iwd/ 2>/dev/null || echo "No saved Wi-Fi found; connect with iwctl after first boot."
cat > /mnt/etc/systemd/network/25-wireless.network <<'EOF'
[Match]
Name=wl*

[Network]
DHCP=yes
EOF

# 6. Configure inside the new system ($1 = hostname, $2 = username, $3 = root UUID)
root_uuid=$(blkid -s UUID -o value "$root_part")
arch-chroot /mnt /bin/bash -euo pipefail -s "$host" "$user" "$root_uuid" <<'EOF'
host=$1 user=$2 root_uuid=$3

ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
sed -i 's/^#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
echo "KEYMAP=uk" > /etc/vconsole.conf
echo "$host" > /etc/hostname

useradd -m -G wheel "$user"
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
visudo -c

systemctl enable systemd-networkd systemd-resolved iwd

# CachyOS kernel repo, above [core]
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47
sed -i '/^\[core\]/i [cachyos]\nServer = https://mirror.cachyos.org/repo/$arch/$repo\n' /etc/pacman.conf
pacman -Sy --noconfirm cachyos-keyring cachyos-mirrorlist
sed -i 's|^Server = https://mirror.cachyos.org/repo/\$arch/\$repo$|Include = /etc/pacman.d/cachyos-mirrorlist|' /etc/pacman.conf

# mkinitcpio first so linux-cachyos doesn't ask which initramfs tool to use;
# --noconfirm accepts the zlib -> zlib-ng-compat replacement
pacman -Syu --noconfirm mkinitcpio
pacman -S --noconfirm linux-cachyos
[[ -f /boot/initramfs-linux-cachyos.img ]] || { echo "initramfs missing from /boot"; exit 1; }

# Bootloader
bootctl install
printf 'default cachyos.conf\ntimeout 3\n' > /boot/loader/loader.conf
cat > /boot/loader/entries/cachyos.conf <<ENTRY
title   Arch Linux (CachyOS kernel)
linux   /vmlinuz-linux-cachyos
initrd  /initramfs-linux-cachyos.img
options root=UUID=$root_uuid rw
ENTRY
EOF

# 7. Passwords (sent on stdin so they never appear in the log or process list)
printf 'root:%s\n%s:%s\n' "$root_pw" "$user" "$user_pw" | arch-chroot /mnt chpasswd

# 8. DNS, save the log, unmount
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
cp /tmp/arch-install.log /mnt/var/log/arch-install.log
umount -R /mnt

echo
echo "Done. Type reboot, remove the USB stick when the screen goes black, and log in as $user."
echo "Then run arch-setup.sh. This log is saved at /var/log/arch-install.log on the new system."
