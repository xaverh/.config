localectl set-keymap de
lsblk
ping google.com
ls /sys/firmware/efi/efivars
timedatectl set-ntp true

# EFI
# don't forget the EFI partition
# https://wiki.archlinux.org/index.php/EFI_System_Partition
gdisk /dev/sdX

# BIOS
# check which filesystems syslinux can handle
fdisk /dev/sdX

# make filesystems
mkfs.ext4 -O encrypt,metadata_csum,64bit /dev/sdX
# mount everything accordingly below /mnt

vi /etc/pacman.d/mirrorlist
pacstrap /mnt base base-devel vim bash-completion

genfstab -U /mnt >> /mnt/etc/fstab # settings for SSDs?
arch-chroot /mnt

passwd

# Intel CPU
pacman -S intel-ucode

# BIOS
pacman -S syslinux
syslinux-install_update -i -m -a
vi /boot/syslinux/syslinux.cfg

# UEFI
bootctl install

# /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=PARTUUID=f69907aa-e58a-4f56-8bc0-208e5f1ad73a rootfstype=xfs add_efi_memmap rw
# :r! lsblk -n -o PARTUUID /dev/sdb1 to get real PARTUUID

# /boot/loader/loader.conf
timeout 3
default arch

# replace "udev" with "systemd" in /etc/mkinitcpio.conf
# MODULES="... crypto-crc32c"
mkinitcpio -p linux

exit

# unmount all devices

reboot

# Locale configuration
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
localectl set-locale LANG=en_US.UTF-8
localectl set-keymap de

# Time configuration
vi /etc/systemd/timesyncd.conf # TODO
timedatectl set-ntp true
timedatectl set-local-rtc false # except on dual boot with Windows
timedatectl set-timezone Europe/Berlin

# network configuration
hostnamectl set-hostname myhostname

echo "[Match]
Name=en*
[Network]
DHCP=yes
[DHCP]
UseDNS=false
RouteMetric=10" > /etc/systemd/network/wired.network

echo "[Match]
Name=wl*
[Network]
DHCP=yes
[DHCP]
UseDNS=false
RouteMetric=20" > /etc/systemd/network/wireless.network

ln -sf /run/systemd/resolve/resolv.conf /etc
vim /etc/systemd/resolved.conf
systemctl enable --now systemd-resolved
systemctl enable --now systemd-networkd

# Install optional packages
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
rankmirrors /etc/pacman.d/mirrorlist > /tmp/mirrorlist
vi /tmp/mirrorlist
mv /tmp/mirrorlist /etc/pacman.d/mirrorlist
vi /etc/pacman.conf
# enable multilib
# enable Color
# add ILoveCandy
pacman -Syu
# find video card
lspci | grep -e VGA -e 3D
# Intel: pacman -S xf86-video-intel mesa-libgl lib32-mesa-libgl vulkan-intel
# NVidia: XXX

pacman --needed -S clang libstdc++5 lua dunst scrot feh \
zathura-{pdf-poppler,ps,djvu,cb} llvm imagemagick gulp pavucontrol \
unrar slock git unzip exfat-utils mpv youtube-dl rtmpdump numlockx npm \
nodejs p7zip xorg{,-apps,-fonts,-xinit} gst-plugins-good gst-libav openmp \
texlive-most pulseaudio pulseaudio-alsa pamixer alsa-utils bc mac \
openssh xclip x11-ssh-askpass go go-tools tmux vifm stow dmenu ncdu vim \
playerctl firefox pcmanfm openvpn adobe-source-{code,sans,serif}-pro-fonts \
adobe-source-han-{sans,serif}-otc-fonts

# optional packages
pacman --needed -S jsoncpp mpd ncmpcpp mpc ranger steam steam-native-runtime \
lib32-gtk3 aria2 w3m cmatrix lolcat iperf3 darktable ttf-linux-libertine gimp ttyload

# Laptop?
pacman --needed -S acpi wpa_supplicant iw wireless_tools # is wireless_tools deprecated?

# XXX
# ln -s /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
vim /etc/wpa_supplicant/wpa_supplicant.conf
chmod a+r /etc/wpa_supplicant/wpa_supplicant.conf
# ctrl_interface=/var/run/wpa_supplicant
# eapol_version=1
# ap_scan=1
# fast_reauth=1
systemctl enable --now wpa_supplicant@wlan0 ## XXX
# wpa_passphrase

# DVD?
pacman --needed -S libdvdcss dvd+rw-tools

# SSD?
systemctl enable fstrim.timer

# users
useradd xha -m -G wheel
passwd xha
visudo
# Defaults insults

reboot
