#!/usr/bin/zsh

localectl set-keymap de
lsblk
ping google.com
ls /sys/firmware/efi/efivars

# efibootmgr
blkdiscard /dev/sdX
sgdisk -Z -o -n 1:0:+200MiB -t 1:ef00 -n 2:0:0 -t 2:8309 /dev/sdX
mkfs.fat -F32 /dev/sdX1

cryptsetup -y --use-random -v --type luks2 luksFormat /dev/sdX2
# SSD?
cryptsetup -y --use-random -v --type luks2 --align-payload=8192 luksFormat /dev/sdX2

cryptsetup open /dev/sdX2 cryptroot
# SSD?
cryptsetup --allow-discards --persistent open /dev/sdX2 cryptroot

mkfs.btrfs /dev/mapper/cryptroot
mount -o compress-force=zstd:6,noatime /dev/mapper/cryptroot /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@/home
mkdir /mnt/@/var
chattr +C /mnt/@/var
mkdir /mnt/@/boot
btrfs subvolume set-default /mnt/@
cd /
umount /mnt
mount -o compress-force=zstd:6,noatime /dev/mapper/cryptroot /mnt
mount /dev/sda1 /mnt/boot

vim /etc/pacman.d/mirrorlist

pacstrap /mnt base linux linux-firmware vim zsh tmux btrfs-progs sudo git stow
# cryptsetup intel-ucode amd-ucode broadcom-wl-dkms iwd xf86-video-intel

# Essentials
mkdir -p /mnt/usr/local/lib/systemd/system
cp ~/etc/Factory/usr-local-lib-systemd-system-slock\\x40.service /mnt/usr/local/lib/systemd/system/slock@.service
cp ~/etc/Factory/etc-systemd-network-05\\x2dwired.network /mnt/etc/systemd/network/05-wired.network
mkdir /mnt/etc/systemd/resolved.conf.d
cp ~/etc/Factory/etc-systemd-resolved.conf.d-20\\x2d1.1.1.1.conf /mnt/etc/systemd/resolved.conf.d/20-1.1.1.1.conf
mkdir -p /mnt/etc/X11/xorg.conf.d
cp ~/etc/Factory/etc-X11-xorg.conf.d-20\\x2ddontzap.conf /mnt/etc/X11/xorg.conf.d/20-dontzap.conf
mkdir -p /mnt/boot/loader/entries
cp ~/etc/Factory/boot-loader-loader.conf /mnt/boot/loader/loader.conf
cp ~/etc/Factory/boot-loader-entries-arch.conf /mnt/boot/loader/entries/arch.conf
mkdir -p /mnt/etc/pacman.d/hooks
cp ~/etc/Factory/etc-pacman.d-hooks-100\\x2dsystemd\\x2dboot.hook /mnt/etc/pacman.d/hooks/100-systemd-boot.hook
cp /etc/pacman.conf /mnt/etc/pacman.conf
echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
echo pts/0  >> /mnt/etc/securetty
mkdir -p /mnt/usr/local/lib/systemd/user
cp ~/etc/Factory/usr-local-lib-systemd-user-ssh\\x2dagent.service /mnt/usr/local/lib/systemd/user/ssh-agent.service

# As needed
cp ~/etc/Factory/etc-X11-xorg.conf.d-15\\x2dintel.conf /mnt/etc/X11/xorg.conf.d/15-intel.conf
cp ~/etc/Factory/etc-X11-xorg.conf.d-30\\x2dinput.conf /mnt/etc/X11/xorg.conf.d/30-input.conf
cp ~/etc/Factory/etc-udev-rules.d-90x2dbacklight.rules /mnt/etc/udev/rules.d/90-backlight.rules
mkdir /mnt/etc/iwd
cp ~/etc/Factory/etc-iwd-main.conf /mnt/etc/iwd/main.conf
# /etc/mkinitcpio.conf
# HOOKS="systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems"
# sd-encrypt only needed if hd is encrypted

systemd-nspawn -D /mnt passwd root
systemd-nspawn -D /mnt chsh -s /usr/bin/zsh
systemd-nspawn -D /mnt useradd -m -N -g users -G video,wheel -s /usr/bin/zsh xha
systemd-nspawn -D /mnt passwd xha
systemd-nspawn -D /mnt locale-gen
cp /mnt/etc/sudoers /mnt/etc/sudoers.d/sudoers
systemd-nspawn -D /mnt --setenv=EDITOR=vim visudo /etc/sudoers.d/sudoers

systemd-nspawn -bD /mnt

pacman -D --asexplicit curl less

pacman-key --add ~/etc/Factory/home_xha_Arch.key
pacman-key --lsign-key home

pacman -S --needed --assume-installed=dmenu --assume-installed=cantarell-fonts --assume-installed=adobe-source-code-pro-fonts --assume-installed=jack --assume-installed=udisks2 unrar zip unzip exfat-utils mupdf-gl ncdu openssh p7zip pulseaudio rmlint clipmenu gimp herbstluftwm rofi mpv nnn youtube-dl pavucontrol slock telegram-desktop xclip xorg-server xorg-xinit nodejs lua discord firefox noto-fonts-emoji chromium go flameshot uw-ttyp0-font wqy-bitmapfont xorg-xinput sent dunst termite strawberry xcursor-vanilla-dmz man-db man-pages feh mons

pacman -S bluez bluez-utils numlockx pulseaudio-bluetooth steam rawtherapee abcde weechat vulkan-intel iw

pacman -S --needed --asdeps x11-ssh-askpass clipnotify xorg-xsetroot npm rtmpdump lemonbar libzip farbfeld jpegexiforient gst-plugins-bad gst-libav gst-plugins-ugly
# as-deps: libdvdcss libva-intel-driver linux-headers crda opus-tools

localectl set-locale LANG=en_US.UTF-8
localectl set-x11-keymap us pc104 altgr-intl compose:menu,rupeesign:4
localectl set-x11-keymap de apple_laptop mac_nodeadkeys compose:rwin-altgr
timedatectl set-ntp true
timedatectl set-timezone Europe/Berlin
hostnamectl set-hostname andermatt
systemctl enable --now systemd-resolved.service
systemctl enable --now systemd-networkd.service
systemctl enable --now systemd-timesyncd.service
systemctl enable iwd.service
systemctl enable bluetooth.service
systemctl enable slock@xha.service
systemctl enable fstrim.timer
systemctl mask systemd-fsck-root.service

vim /etc/conf.d/wireless-regdom

systemctl edit getty@tty1
# [Service]
# ExecStart=
# ExecStart=-/usr/bin/agetty --skip-login --nonewline --noissue --autologin xha --noclear %I $TERM

bootctl install

mkinitcpio -p linux
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

exit
reboot

# As user
xdg-mime default mupdf.desktop application/pdf application/vnd.comicbook-rar application/vnd.comicbook+zip application/epub+zip application/x-cb7
xdg-mime default feh.desktop image/jpeg image/png image/gif image/tiff image/webp image/x-xpmi

npm -g i @vue/cli generator-code gulp-cli sass vsce yo

code --install-extension bierner.markdown-checkbox --install-extension bierner.markdown-footnotes --install-extension bierner.markdown-mermaid --install-extension dbaeumer.vscode-eslint --install-extension eg2.vscode-npm-script --install-extension esbenp.prettier-vscode --install-extension firefox-devtools.vscode-firefox-debug --install-extension James-Yu.latex-workshop --install-extension ms-python.python --install-extension ms-vscode.cpptools --install-extension ms-vscode.Go --install-extension ms-vscode.vscode-typescript-tslint-plugin --install-extension msjsdiag.debugger-for-chrome --install-extension nhoizey.gremlins --install-extension octref.vetur --install-extension pflannery.vscode-versionlens --install-extension sdras.night-owl --install-extension sdras.vue-vscode-snippets --install-extension trixnz.vscode-lua --install-extension twxs.cmake --install-extension VisualStudioExptTeam.vscodeintellicode --install-extension wmaurer.change-case --install-extension xaver.clang-format --install-extension xaver.theme-qillqaq --install-extension xaver.theme-ysgrifennwr

systemctl --user enable --now ssh-agent.service
systemctl --user enable --now clipmenud.service
