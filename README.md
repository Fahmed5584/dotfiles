# XPS-13 Laptop Setup Guide.

Nov 4, 2026 · @Faisal

## Overview

This guide installs a minimal Arch Linux on a laptop, with the CachyOS kernel and the Hyprland window manager.

**What you end up with:**

- A password login at a plain bash prompt. Hyprland starts only when you type `start-hyprland`.
- Only the packages listed in this guide, nothing else.
- A firewall that lets in only SSH and Syncthing from your home network, and SSH that accepts keys only.

**Two ways to install:**

- **Scripted:** two scripts do the work. See *Scripted install* below.
- **By hand:** Parts 1–11 do the same thing step by step and explain each choice.

**You will need:**

- A USB stick (2 GB or more), and a second device to read this guide on
- Your Wi-Fi network name and password
- The laptop, plugged into power. **Everything on its disk will be wiped.**
- A second computer on your home network (192.168.50.x) to SSH in from
- About 1–2 hours by hand, less with the scripts

**Conventions:** lines in code blocks are commands to type. Anything in `<angle brackets>` is a placeholder to replace with your own value, without the brackets. `/dev/sda` is the example disk; check yours with `lsblk` (Part 2) before wiping anything.

The [Arch Wiki Installation Guide](https://wiki.archlinux.org/title/Installation_guide) is the official reference. This guide follows it, with the choices made for you.

## Scripted install

Two scripts do everything in Parts 2–10 for you. Part 11 covers the few steps you finish by hand either way. The manual parts below do the same work by hand and explain each step.

Do steps 1–4 of *B**e**f**o**r**e** **y**o**u** **s**t**a**r**t* below: write the ISO to a USB stick, turn off Secure Boot, and check UEFI and AHCI.

1. **Boot the USB and get online:**

   ```
   loadkeys uk
   iwctl station wlan0 connect "<network name>"
   ping -c 3 archlinux.org
   ```
2. **Run the install script:**

   ```
   curl -fsSLO https://raw.githubusercontent.com/Fahmed5584/dotfiles/main/xps-arch-install.sh
   bash xps-arch-install.sh
   ```

   It asks for the disk (press Enter for `sda`), a computer name, your username and two passwords, then asks you to type `sda` to confirm the wipe. After that it runs on its own; it copies your Wi-Fi connection onto the new system too.
3. **Reboot** when it says Done, remove the USB stick when the screen goes black, and log in as your user.
4. **Run the setup script:**

   ```
   curl -fsSLO https://raw.githubusercontent.com/Fahmed5584/dotfiles/main/xps-arch-setup.sh
   bash xps-arch-setup.sh
   ```

   It asks for your password for `sudo`. If it says the kernel was updated, type `reboot`, log back in and run `bash xps-arch-setup.sh` again.
5. **Finish by hand:** run `start-hyprland`, pair Syncthing at `http://127.0.0.1:8384` in qutebrowser, paste your public key from KeePassXC into `~/.ssh/authorized_keys`, and test SSH from your other computer.

**If a script fails,** it stops and prints `FAILED at line N` with the command that failed. Note that line. The install log is at `/tmp/arch-install.log` on the USB, or `/var/log/arch-install.log` on the new system. To retry `xps-arch-install.sh`, run `umount -R /mnt` first, then run the script again; it wipes the disk and starts over. `xps-arch-setup.sh` can simply be run again.

## Before you start

Back up anything on the laptop first: Part 2 erases the whole disk.

1. **Download the ISO** from [archlinux.org/download](https://archlinux.org/download/) (pick a UK mirror or the torrent). The ISO is a complete live system that runs from the USB stick, and you install from inside it.
2. **Check the download isn't corrupted.** On Linux:

   ```
   sha256sum archlinux-*.iso
   ```

   Compare the output with the SHA256 checksum on the download page. If they differ, download it again rather than risk a half-working installer.
3. **Write it to the USB stick.** On Linux, find the stick's name with `lsblk`, then (this wipes the stick):

   ```
   sudo dd if=archlinux-<version>-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```

   Use the stick itself (e.g. `/dev/sdb`), not a partition like `/dev/sdb1`. `dd` overwrites whatever you point it at without asking, so double-check the name.
4. **Set up the firmware** (usually F2, F12 or Del at power-on):
   - Turn off **Secure Boot**. The Arch ISO and the CachyOS kernel aren't signed with the keys laptops trust out of the box.
   - Make sure boot mode is **UEFI**, not Legacy or CSM. The bootloader this guide uses, systemd-boot, only works with UEFI.
   - If there's a **SATA Operation** setting, set it to **AHCI**, not RAID. In RAID mode Linux may not see the drive at all.
5. **Boot from the USB** (often F12 gives a one-time boot menu) and choose the first menu entry.

## Part 1: Get the live system ready

You land at a root prompt (`root@archiso ~ #`). This system runs entirely in RAM: nothing you do here touches the laptop's disk until Part 2.

1. **UK keyboard layout.** The default is US, which moves keys such as `"`, `@`, `|` and `#`:

   ```
   loadkeys uk
   ```
2. **Text too small?** On high-resolution screens the console text can be tiny:

   ```
   setfont ter-132b
   ```

   `ter-124b` is a size smaller and `ter-116n` smaller still.
3. **Confirm you booted in UEFI mode:**

   ```
   cat /sys/firmware/efi/fw_platform_size
   ```

   It should print `64`. If the file doesn't exist, the laptop booted the USB in legacy mode: go back to the firmware settings.
4. **Connect to Wi-Fi** with `iwctl`, the iwd Wi-Fi tool:

   ```
   iwctl
   device list
   station wlan0 scan
   station wlan0 get-networks
   station wlan0 connect "<network name>"
   exit
   ```

   The first line opens iwctl's own prompt, and the rest are typed inside it. `device list` shows your Wi-Fi card's name; use it in place of `wlan0` if it's different. You're asked for the Wi-Fi password after `connect`. iwd saves the network, and Part 3 copies it onto the new system so you don't have to do this again.
5. **Check you're online and sync the clock:**

   ```
   ping -c 3 archlinux.org
   timedatectl set-ntp true
   ```

   The clock matters: package signature checks and HTTPS both fail if the time is badly wrong.

## Part 2: Partition, format and mount the disk

The layout is two partitions: a small boot partition the firmware can read, and everything else for the system. There's no swap partition; you can add a swap file or zram later if you ever need it.

| Partition | Size | Type | Format | Mounted at |
| --- | --- | --- | --- | --- |
| `/dev/sda1` | 1 GiB | EFI System | FAT32 | `/boot` |
| `/dev/sda2` | rest of disk | Linux filesystem | ext4 | `/` |

1. **Find your disk:**

   ```
   lsblk
   ```

   Look for the internal drive by its size, and ignore the USB stick and `loop0`. A SATA drive is named like `sda`, with partitions `sda1` and `sda2`. An NVMe drive is named like `nvme0n1`, with partitions `nvme0n1p1` and `nvme0n1p2`. This guide uses `sda`.
2. **Partition it** with `cfdisk`, a menu-driven partition editor:

   ```
   cfdisk /dev/sda
   ```
   1. If asked for a label type, choose **gpt**, the modern partition table that UEFI expects.
   2. Delete any existing partitions (select each, then **Delete**).
   3. **New** → `1G` → **Type** → **EFI System**.
   4. Move to the free space → **New** → accept the full size. The type stays **Linux filesystem**.
   5. **Write** → type `yes` → **Quit**. Nothing changes on the disk until you choose Write.
3. **Format:**

   ```
   mkfs.fat -F 32 /dev/sda1
   mkfs.ext4 /dev/sda2
   ```

   The boot partition must be FAT32, because that's the filesystem UEFI firmware can read. ext4 is Linux's standard, well-tested filesystem, used for everything else.
4. **Mount them** where the new system will be built, root first and then boot inside it:

   ```
   mount /dev/sda2 /mnt
   mount --mkdir /dev/sda1 /mnt/boot
   ```

   `--mkdir` creates the `/mnt/boot` folder before mounting. Check with `lsblk`: it should now show `/mnt` and `/mnt/boot` against the two partitions.

## Part 3: Install the base system

`pacstrap` installs packages into `/mnt`, the new system, instead of into the live USB:

```
pacstrap -K /mnt base linux-firmware intel-ucode sudo neovim iwd
```

`-K` gives the new system its own fresh set of package signing keys.

| Package | Why it's needed |
| --- | --- |
| `base` | The core system: systemd, pacman, bash and the standard command-line tools |
| `linux-firmware` | Firmware for graphics, Wi-Fi and other hardware |
| `intel-ucode` | CPU bug and security fixes for Intel processors, loaded at boot. Use `amd-ucode` on AMD |
| `sudo` | Run admin commands as your normal user |
| `neovim` | Text editor, run as `nvim` |
| `iwd` | Wi-Fi |

**No kernel is installed here on purpose.** Arch's stock `linux` package is left out, and the CachyOS kernel goes in during Part 4. Networking (systemd-networkd), DNS (systemd-resolved) and the bootloader (systemd-boot) are all part of systemd, which `base` already includes, so they need no extra packages.

Two more steps, still from the live USB:

1. **Record the partitions** so the new system mounts them at every boot:

   ```
   genfstab -U /mnt >> /mnt/etc/fstab
   cat /mnt/etc/fstab
   ```

   `-U` refers to each partition by its UUID, an ID that stays the same even if drive names change. **Run it only once:** `>>` adds to the file, so a second run duplicates every entry. The file should have exactly one line for `/` and one for `/boot`.
2. **Copy your Wi-Fi connection** onto the new system, so it's online from the first boot:

   ```
   mkdir -p -m 700 /mnt/var/lib/iwd
   cp /var/lib/iwd/*.psk /mnt/var/lib/iwd/
   ```

   iwd stores each network you join as a `.psk` file holding its name and password. `700` makes the folder readable by root only, since those files contain your Wi-Fi password.

## Part 4: Configure the new system

`arch-chroot` switches into the installed system, so the commands that follow act on it rather than on the live USB:

```
arch-chroot /mnt
```

The prompt changes to `[root@archiso /]#`. `arch-chroot` must have `/mnt` after it; on its own it fails with "No chroot directory specified".

**Editing files:** this part uses Neovim. Open a file with `nvim <file>` and press `i` to start typing. Then press `Esc`, type `:wq` and press Enter to save and quit; `:q!` quits without saving.

1. **Time zone and hardware clock:**

   ```
   ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
   hwclock --systohc
   ```

   The first command links `/etc/localtime`, where the system looks up its time zone, to London's, which includes the GMT/BST switch. The second copies the system time to the laptop's battery-backed hardware clock, so the time is right at the next boot. Neither prints anything when it works.
2. **Language:**

   ```
   nvim /etc/locale.gen
   ```

   Find `#en_GB.UTF-8 UTF-8`, delete the `#` at the start, then save and quit. Then build the locale and make it the default:

   ```
   locale-gen
   echo "LANG=en_GB.UTF-8" > /etc/locale.conf
   ```

   The locale sets the language, date and number formats, and sort order. Only the locales you uncomment get built.
3. **Keyboard layout** for the text console. This makes Part 1's `loadkeys uk` permanent:

   ```
   echo "KEYMAP=uk" > /etc/vconsole.conf
   ```

   If the console text is tiny after the first boot, install `terminus-font` and add a `FONT=ter-132b` line to this file.
4. **Computer name**, shown on your network and in the prompt:

   ```
   echo "<hostname>" > /etc/hostname
   ```
5. **Root password:**

   ```
   passwd
   ```
6. **Your user** (lowercase, no spaces) and its password:

   ```
   useradd -m -G wheel <username>
   passwd <username>
   ```

   `-m` creates your home folder. `wheel` is the traditional admin group, and the next step lets its members use `sudo`.
7. **Allow `sudo` for the wheel group:**

   ```
   echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/wheel
   chmod 440 /etc/sudoers.d/wheel
   visudo -c
   ```

   This adds a small file of its own instead of editing the main `/etc/sudoers`, so package updates never clash with your change. `440` makes it read-only, which sudo requires. `visudo -c` checks every sudo file for mistakes, and should end with `parsed OK`. Don't skip it: a broken sudo file can lock you out of `sudo`.
8. **Networking.** Create a config file that tells systemd-networkd to get an address for any Wi-Fi card:

   ```
   nvim /etc/systemd/network/25-wireless.network
   ```

   Contents:

   ```
   [Match]
   Name=wl*
   
   [Network]
   DHCP=yes
   ```

   `wl*` matches any Wi-Fi interface name, and `DHCP=yes` asks the router for an address. Then turn on networking, DNS and Wi-Fi at boot. **This is one line**, even if it wraps on your screen:

   ```
   systemctl enable systemd-networkd systemd-resolved iwd
   ```

   Success shows a few `Created symlink` lines. iwd joins the Wi-Fi network, systemd-networkd sets up the address and routes, and systemd-resolved looks up names.
9. **Add the CachyOS kernel repository.** Arch stays the main source of packages; this adds CachyOS's repository for its kernel.
   1. Trust CachyOS's signing key, so pacman can verify their packages:

      ```
      pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
      pacman-key --lsign-key F3B607488DB35A47
      ```
   2. Open `/etc/pacman.conf` with `nvim` and add these lines **above** the `[core]` line:

      ```
      [cachyos]
      Server = https://mirror.cachyos.org/repo/$arch/$repo
      ```

      pacman checks repositories from top to bottom, so a package that exists in both comes from CachyOS.
   3. Install CachyOS's keyring and mirror list:

      ```
      pacman -Sy cachyos-keyring cachyos-mirrorlist
      ```
   4. Reopen `/etc/pacman.conf` and replace the `Server = ...` line under `[cachyos]` with:

      ```
      Include = /etc/pacman.d/cachyos-mirrorlist
      ```

      This spreads downloads across all of CachyOS's mirrors instead of relying on one.
10. **Install the CachyOS kernel:**

    ```
    pacman -Syu mkinitcpio
    pacman -S linux-cachyos
    ```

    `mkinitcpio` builds the initramfs, a small startup image the kernel loads first to find and mount your disk. Installing it first means pacman doesn't stop to ask which initramfs tool you want. If pacman asks **"Replace zlib with cachyos/zlib-ng-compat?"**, answer **y**: it's a faster drop-in replacement for the zlib compression library, and every program works with it. If you ever remove the CachyOS repo, switch back first with `pacman -S core/zlib`.

    Check with `ls /boot`: you should see `vmlinuz-linux-cachyos` and `initramfs-linux-cachyos.img`. The CPU fixes from `intel-ucode` are bundled into the initramfs automatically.
11. **Bootloader (systemd-boot):**

    ```
    bootctl install
    ```

    This copies systemd-boot onto the boot partition and registers it with the laptop's firmware. Now write its settings:

    ```
    nvim /boot/loader/loader.conf
    ```

    Contents:

    ```
    default cachyos.conf
    timeout 3
    ```

    That boots the CachyOS entry by default and shows the menu for 3 seconds. Next, create the boot entry. The first command writes the entry's last line for you, filling in the root partition's UUID, which is long and easy to mistype:

    ```
    echo "options root=UUID=$(blkid -s UUID -o value /dev/sda2) rw" > /boot/loader/entries/cachyos.conf
    nvim /boot/loader/entries/cachyos.conf
    ```

    Add these three lines **above** the `options` line:

    ```
    title   Arch Linux (CachyOS kernel)
    linux   /vmlinuz-linux-cachyos
    initrd  /initramfs-linux-cachyos.img
    ```

    `linux` and `initrd` name the kernel and startup image on the boot partition. `options` tells the kernel which partition holds `/`, and to mount it read-write.

## Part 5: Leave, finish DNS and reboot

```
exit
ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
umount -R /mnt
reboot
```

`exit` leaves the chroot. The second line points the new system's DNS settings at systemd-resolved. It has to be done from outside, because `arch-chroot` temporarily covers that file with the live USB's own copy. `umount -R` unmounts both partitions cleanly before the restart. Remove the USB stick when the screen goes black.

## Part 6: First boot and packages

After the boot menu you get a text login prompt. Log in as **your user**, not root. Every login lands here, at a bash prompt; nothing graphical starts on its own.

1. **Check you're online.** The Wi-Fi copied in Part 3 should connect by itself:

   ```
   ping -c 3 archlinux.org
   ```

   If it fails, connect once with `iwctl station wlan0 connect "<network name>"`.
2. **Update everything:**

   ```
   sudo pacman -Syu
   ls /usr/lib/modules/$(uname -r)
   ```

   The second line checks whether the update replaced the kernel. If it says "No such file or directory", the running kernel's modules have been swapped for the new kernel's. Reboot before carrying on, or the firewall in Part 7 can't load the modules it needs.
3. **Install the packages.** They're grouped by purpose, and the table below says what each is for:

   ```
   sudo pacman -S brightnessctl less man-db rsync
   sudo pacman -S pipewire wireplumber pipewire-pulse
   sudo pacman -S hyprland kitty wl-clipboard mako fuzzel
   sudo pacman -S ttf-dejavu ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common
   sudo pacman -S vulkan-intel intel-media-driver
   sudo pacman -S git github-cli fzf ripgrep fd
   sudo pacman -S qutebrowser keepassxc qt6-wayland syncthing
   sudo pacman -S ufw openssh
   ```

   If pacman asks you to choose between providers, press Enter for the default. On AMD graphics, install `vulkan-radeon` instead of `vulkan-intel` and skip `intel-media-driver`.

| Package | What it's for |
| --- | --- |
| `brightnessctl` | Screen brightness from any prompt, e.g. `brightnessctl set 50%` |
| `less`, `man-db`, `rsync` | Scrolling through long output (`q` quits), manual pages (e.g. `man rsync`), and copying or backing up files |
| `pipewire`, `wireplumber`, `pipewire-pulse` | Sound: PipeWire is the sound server, WirePlumber decides which device plays what, and `pipewire-pulse` lets apps built for PulseAudio use PipeWire |
| `hyprland` | The Wayland compositor that draws and manages your windows |
| `kitty` | Terminal |
| `wl-clipboard` | `wl-copy` and `wl-paste`, the Wayland clipboard; Neovim uses them |
| `mako`, `fuzzel` | Desktop notifications, and an app launcher |
| `ttf-dejavu` | A basic font; kitty shows no text without at least one |
| `ttf-jetbrains-mono` | A coding font |
| `ttf-nerd-fonts-symbols`, `ttf-nerd-fonts-symbols-common` | Nerd Font icons, and the settings that let other fonts borrow them |
| `vulkan-intel`, `intel-media-driver` | Vulkan and hardware video decoding for Intel graphics. Mesa, the base graphics driver, comes with Hyprland |
| `git`, `github-cli` | Downloading your configs, and the `gh` command for GitHub |
| `fzf`, `ripgrep`, `fd` | Used by your Neovim config's fzf-lua finder: `fzf` itself, text search for `<leader>fg` and file listing for `<leader>ff` |
| `qutebrowser`, `keepassxc` | Web browser and password manager |
| `qt6-wayland` | Lets those two Qt apps run natively on Wayland |
| `syncthing` | Keeps folders in sync between your devices |
| `ufw`, `openssh` | Firewall, and the SSH server |

**Bash is your shell** and needs no setup. Use `~/.bash_profile` for things that should run once at login, and `~/.bashrc` for aliases and prompt changes, which apply in every terminal.

## Part 7: Firewall

The firewall blocks every incoming connection except SSH and Syncthing from your home network. Outgoing connections are all allowed, so browsing and updates work normally.

1. **Set the rules:**

   ```
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw allow from 192.168.50.0/24 to any port 22 proto tcp
   sudo ufw allow from 192.168.50.0/24 to any port 22000 proto tcp
   sudo ufw allow from 192.168.50.0/24 to any port 22000 proto udp
   sudo ufw allow from 192.168.50.0/24 to any port 21027 proto udp
   ```

   `192.168.50.0/24` means any address from 192.168.50.0 to 192.168.50.255, which is your home network. Port 22 is SSH. Port 22000 (TCP and UDP) carries Syncthing's file transfers, and 21027/UDP is how Syncthing finds your other devices on the network. Nothing listens on these ports until Parts 9 and 10, so opening them now is harmless and keeps all the firewall setup in one place.
2. **Turn it on, now and at every boot:**

   ```
   sudo ufw enable
   sudo systemctl enable --now ufw
   sudo ufw status verbose
   ```

   `ufw enable` applies the rules immediately; answer `y` if it asks. The `systemctl` line loads them again at every boot. The status should show `deny (incoming)` and four rules, each limited to 192.168.50.0/24.

## Part 8: Your configs from GitHub

Your Hyprland and Neovim configs live in your dotfiles repo:

```
git clone https://github.com/Fahmed5584/dotfiles ~/dotfiles
bash ~/dotfiles/xps-dotfile-install.sh
```

`xps-dotfile-install.sh` copies everything in the repo's `hyprland/` folder into `~/.config/hypr/`, and `nvim/init.lua` into `~/.config/nvim/`, creating both folders if needed. It overwrites files with the same name and leaves anything else there alone. To pick up later changes, run `git -C ~/dotfiles pull` and then the script again. Run `gh auth login` when you want to push changes back to GitHub.

Since Hyprland 0.55 the config is a Lua file, `hyprland.lua`, rather than `hyprland.conf`. Your Neovim config downloads its plugins itself: fzf-lua the first time you start `nvim`, and vim-table-mode the first time you open a Markdown file. Each needs the internet once; confirm if Neovim asks.

## Part 9: Services that start at login

Syncthing and the sound system run as *your* user rather than as root, so they can reach your files and your login session:

```
systemctl --user enable --now syncthing.service pipewire.socket pipewire-pulse.socket wireplumber.service
```

- `--user` manages your own services, so there's no `sudo`.
- `enable` starts them at every login, even at the text prompt, and they stop when you log out.
- `--now` also starts them straight away. Without it, services installed during this login wouldn't run until you logged in again, which is why sound was silent on the first install.
- PipeWire's two `.socket` units start the sound server the moment an app wants to play sound, rather than keeping it running all the time.

Check sound works, then set a volume:

```
wpctl status
wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%
```

`wpctl status` should list the laptop's speakers under **Sinks**. If the only sink is **Dummy Output**, PipeWire can't see the sound card. To keep Syncthing syncing while you're logged out, run `sudo loginctl enable-linger <username>` once.

## Part 10: SSH, keys only

SSH lets you log in to the laptop from another computer. It's set up to accept only keys, never passwords. Starting it before you've added a key is safe: with passwords off and no key in place, nobody can log in yet. You add your key in Part 11.

1. **Create the key file** with the permissions SSH insists on:

   ```
   mkdir -p -m 700 ~/.ssh
   touch ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

   SSH ignores keys in a folder or file that anyone else could change, so the folder is yours alone (`700`) and the file is readable and writable only by you (`600`).
2. **Lock SSH down.** Create a settings file:

   ```
   sudo nvim /etc/ssh/sshd_config.d/10-hardening.conf
   ```

   Contents:

   ```
   PermitRootLogin no
   PasswordAuthentication no
   KbdInteractiveAuthentication no
   PubkeyAuthentication yes
   AuthenticationMethods publickey
   AllowUsers <username>
   ```

   This blocks root logins and every kind of password login, accepts keys only, and allows only your user. Arch reads the files in `sshd_config.d` before the main config, and sshd uses the first value it finds for each setting, so these always win.
3. **Check the settings, then start SSH:**

   ```
   sudo ssh-keygen -A
   sudo sshd -t
   sudo systemctl enable --now sshd
   ```

   `ssh-keygen -A` creates the laptop's own host keys, which identify it to computers connecting in and which `sshd -t` needs before it can check the config. `sshd -t` prints nothing if everything is valid. The last line starts SSH now and at every boot.

## Part 11: Finish by hand

Both the scripted and manual installs end here.

1. **Start Hyprland:**

   ```
   start-hyprland
   ```

   `start-hyprland` runs Hyprland under a small watchdog. Your config sets the keybinds, including the ones that open kitty and fuzzel and the one that exits back to the text prompt. If a config change ever breaks Hyprland, you're still at a normal bash prompt: fix the file with `nvim ~/.config/hypr/hyprland.lua` and run `start-hyprland` again. `Ctrl+Alt+F2` and up give you extra text logins if you need a second prompt.
2. **Pair Syncthing.** Open `http://127.0.0.1:8384` in qutebrowser and add your other devices. They connect through the ports opened in Part 7. The setup page itself is reachable only from the laptop.
3. **Add your SSH key.** In KeePassXC, copy your public key (the single line starting `ssh-ed25519` or similar). Then:

   ```
   nvim ~/.ssh/authorized_keys
   ```

   Press `i`, paste with `Ctrl+Shift+V`, then press `Esc`, type `:wq` and press Enter. Each key must stay on one line; put any further keys on lines of their own.
