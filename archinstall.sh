#!/bin/bash

set -e

# +-+-+-+-+-+
# Variables
# +-+-+-+-+-+

DRIVE="/dev/mmcblk0"
DRIVE_PART1=${DRIVE}p1
DRIVE_PART2=${DRIVE}p2
DRIVE_PART3=${DRIVE}p3

TIMEZONE="America/Toronto"
REGION="en_CA.UTF-8 UTF-8" 
LANGUAGE="en_CA.UTF-8"
KEYMAP="us"

HOSTNAME="archlinuxbox"

ARCH_USER="archlinuxuser"
ROOT_PSW="archlinuxroot"
USER_PSW="archlinuxpsw"

MIRROR_LINK="https://archlinux.org/mirrorlist/?country=CA&protocol=https&ip_version=4"


# 
# DEPENDENCIES
#

pacman -Sy > /dev/null

if ! pacman -Qs dmidecode > /dev/null ; then
	pacman -S dmidecode --noconfirm > /dev/null
fi

if ! pacman -Qs wget > /dev/null ; then
	pacman -S wget --noconfirm > /dev/null
fi

if ! pacman -Qs pacman-contrib > /dev/null ; then
	pacman -S pacman-contrib --noconfirm > /dev/null
fi

# +-+-+-+-+-+-+-+-+-+-+-+-
# Enable Mirrors
# +-+-+-+-+-+-+-+-+-+-+-+-

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.original
wget -O /etc/pacman.d/mirrorlist.backup $MIRROR_LINK
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
pacman -Sy > /dev/null

#
# function AVAILABLE_MEMORY
#

function available_memory () {
	
  physical_memory=$(
	dmidecode -t memory |
	awk '$1 == "Size:" && $2 ~ /^[0-9]+$/ {print $2$3}' |
	numfmt --from=iec --suffix=B |
	awk '{total += $1}; END {print total}' |
	numfmt --to=iec --suffix=B --format=%0f
  )


  SWAP_SIZE=${physical_memory%.*}
  SWAP_SIZE=$((SWAP_SIZE+1))
  SWAP_SIZE=$((SWAP_SIZE * 1024))
  SWAP_SIZE=$((SWAP_SIZE + 129))

}


# +-+-+-+-+-+-+-+-+-+-+-+-+
# Update the system clock 
# +-+-+-+-+-+-+-+-+-+-+-+-+

timedatectl set-ntp true

# +-+-+-+-+-+-+-+-+-+-+
# Partition the disks
# +-+-+-+-+-+-+-+-+-+-+

available_memory

wipefs -a $DRIVE

# dd if=/dev/zero of=$DRIVE bs=512 count=1 

parted -a optimal $DRIVE --script mklabel gpt
parted -a optimal $DRIVE --script unit mib

parted -a optimal $DRIVE --script mkpart primary 1 129
parted -a optimal $DRIVE --script name 1 boot
parted -a optimal $DRIVE --script set 1 boot on

parted -a optimal $DRIVE --script mkpart primary 129 $SWAP_SIZE
parted -a optimal $DRIVE --script name 2 swap 

parted -a optimal $DRIVE --script mkpart primary $SWAP_SIZE -- -1
parted -a optimal $DRIVE --script name 3 rootfs

# +-+-+-+-+-+-+-+-+-+-+-+-+
# Format the partitions
# +-+-+-+-+-+-+-+-+-+-+-+-+

mkfs.fat -F32 ${DRIVE_PART1}
mkswap ${DRIVE_PART2}
swapon ${DRIVE_PART2}
mkfs.ext4 ${DRIVE_PART3}

# +-+-+-+-+-+-+-+-+-+-+-+-
# Mount the file systems
# +-+-+-+-+-+-+-+-+-+-+-+-

mount /${DRIVE_PART3} /mnt
mkdir /mnt/boot
mount ${DRIVE_PART1} /mnt/boot

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-
# Install essential packages
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-

EDITOR="vim"
NETWORKING="iwd broadcom-wl"
DEPENDENCIES="go git wget"
OPENSSH="openssh"
OTHERS="neofetch"

pacstrap /mnt base base-devel linux linux-firmware man-db man-pages texinfo grub efibootmgr $EDITOR $NETWORKING $DEPENDENCIES $OTHERS $OPENSSH

# +-+-+-+
# FSTAB
# +-+-+-+

genfstab -U /mnt >> /mnt/etc/fstab

#
# CHROOT SCRIPT
#

arch-chroot /mnt /bin/bash << EOF

# +-+-+-+-+-+ 
# TIME ZONE
# +-+-+-+-+-+

ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# +-+-+-+-+-+-+-
# LOCALIZATION
# +-+-+-+-+-+-+-

sed -i "s/#${REGION}/${REGION}/" /etc/locale.gen

locale-gen

printf "LANG=${LANGUAGE}" > /etc/locale.conf 

printf "KEYMAP=${KEYMAP}" > /etc/vconsole.conf


#
# NETWORK CONFIGURATION
#

printf "${HOSTNAME}" > /etc/hostname

printf "127.0.0.1       localhost\n" > /etc/hosts
printf "::1             localhost\n" >> /etc/hosts
printf "127.0.0.1       ${HOSTNAME}\n" >> /etc/hosts

# +-+-+-+-+-+-+-+
# ROOT PASSWORD
# +-+-+-+-+-+-+-+

echo "root:${ROOT_PSW}" | chpasswd

# +-+-+-+-+-+-
# BOOTLOADER
# +-+-+-+-+-+-

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

grub-mkconfig -o /boot/grub/grub.cfg

# +-+-+-+-+-+
# SHORTCUTS
# +-+-+-+-+-+

ln -s /usr/bin/vim /usr/bin/vi

# +-+-+-+-+-+-+-+-+
# SYSTEMD-NETWORKD
# +-+-+-+-+-+-+-+-+

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

cat > /etc/systemd/network/10-dhcp.network << "EOT"
[Match]
Name=*

[Network]
DHCP=ipv4
EOT

# +-+-+-+-+-+-+-+
# ENABLE OPENSSH
# +-+-+-+-+-+-+-+

systemctl enable sshd

# +-+-+-+-+-+-
# ENABLE IWD
# +-+-+-+-+-+-

systemctl enable iwd.service

# +-+-+-+-+-+-+
# CREATE USER
# +-+-+-+-+-+-+

useradd -m -G wheel -s /bin/bash $ARCH_USER

echo "${ARCH_USER}:${USER_PSW}" | chpasswd

sed -i 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

# +-+-+-+-+-+-+
# INSTALL YAY
# +-+-+-+-+-+-+

cd /home/$ARCH_USER
sudo -u $ARCH_USER git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $ARCH_USER makepkg -s
pacman -U ./yay-*.pkg.tar.zst --noconfirm
cd /home/$ARCH_USER
rm -rf yay/

# +-+-+-+-+
# BASHRC
# +-+-+-+-+


printf "\n" >> /etc/profile
printf "\necho \"\"\nneofetch\n\n" >> /etc/profile
printf "alias reboot=\"sudo systemctl reboot\"\n" >> /etc/profile
printf "alias poweroff=\"sudo systemctl poweroff\"\n" >> /etc/profile
printf "alias halt=\"sudo systemctl halt\"\n" >> /etc/profile

# +-+-+-+-+-+-+-+-+-+-
# LOGIN AUTOMATICALLY
# +-+-+-+-+-+-+-+-+-+-

mkdir -p /etc/systemd/system/getty@tty1.service.d/

printf "[Service]\n" > /etc/systemd/system/getty@tty1.service.d/override.conf 
printf "ExecStart=\n" >> /etc/systemd/system/getty@tty1.service.d/override.conf 
printf "ExecStart=-/usr/bin/agetty --autologin $ARCH_USER --noclear %%I \$" >> /etc/systemd/system/getty@tty1.service.d/override.conf 
printf "TERM" >> /etc/systemd/system/getty@tty1.service.d/override.conf 


# +-+-+-+-+-+-+-+-+
# CONNECT WIRELESS
# +-+-+-+-+-+-+-+-+

cat > "/var/lib/iwd/Nautilus-5G 2nd Floor.psk" << "EOT"
[Security]
PreSharedKey=940ccfa5aeaeaa5086998534d94790bdcbb07f7dc7d16fee4ff2eb8ab4072765
Passphrase=BadRaccoon73
EOT

EOF

#
# DONE
#

