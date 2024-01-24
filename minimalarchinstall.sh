#!/bin/bash

# set -e  # Script must stop if there is an error.

# set -x

# +-+-+-+-+-
# VARIABLES
# +-+-+-+-+-

FIRMWARE="UEFI"                # Choose BIOS or UEFI

DRIVE="/dev/sda"               # This drive will be formatted
DRIVE_PART1=${DRIVE}1          # boot partition
DRIVE_PART2=${DRIVE}2          # swap partition
DRIVE_PART3=${DRIVE}3          # root partition

TIMEZONE="America/Toronto"   
REGION="en_CA.UTF-8 UTF-8"     
LANGUAGE="en_CA.UTF-8"
KEYMAP="us"

HOSTNAME="archlinuxbox"

ARCH_USER="archlinuxuser"
USER_PSW="archlinuxpsw"
ROOT_PSW="archlinuxroot"

REFLECTOR_COUNTRY="Canada"

# +-+-+-+-+-+-
# COLOR CODES
# +-+-+-+-+-+-

BLUE='\033[1;34m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BCK_RED='\033[1;41m'
NC='\033[0m'

#
# FUNCTIONS
# ========
# 

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# AVAILABLE_MEMORY
# ================
#
# Will determine what is the current memory,
# add 1GB to it and make it the swap size when
# formatting the HD.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

function make_swap_size () {
	
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

  if [ ${FIRMWARE} = "BIOS" ]; then
    SWAP_SIZE=$((SWAP_SIZE + 2176))
  else 
    SWAP_SIZE=$((SWAP_SIZE + 129))
  fi

}

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-
# YES_OR_NO (question, default answer)
# =========
#
# Ask a yes or no question.
# $1: Question
# $2: Default answer (Y or N)
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-

function yes_or_no {

   QUESTION=$1
   DEFAULT_ANSWER=$2
   DEFAULT_ANSWER=${DEFAULT_ANSWER^^}
  
   Y_N_ANSWER=""
   until [ "$Y_N_ANSWER" == Y ] || [ "$Y_N_ANSWER" == N ]; do

      yn=""
 
      printf "${QUESTION}"
      if [ ${DEFAULT_ANSWER} == "Y" ]
        then
	  printf " ${WHITE}[Y/n]: ${NC}"
          read yn
        else
	  printf " ${WHITE}[y/N]: ${NC}"
          read yn
      fi

      if [ "$yn" == "" ]
        then Y_N_ANSWER=$DEFAULT_ANSWER
      fi

      case $yn in
         [Yy]*) Y_N_ANSWER="Y" ;;
         [Nn]*) Y_N_ANSWER="N" ;;
      esac

   done

   Y_N_ANSWER=${Y_N_ANSWER^^}

}

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
#
# COUNTSLEEP (message, secs delay)
#
# This function is used to pause the 
# installation at start with a message 
# for x seconds.
#
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

function countsleep {
  
  MESSAGE=$1
  END=$2
  TIME_REMAINING=$((END+1))
  
  for ((i = 1; i <= ${END}; i++)); do
    TIME_REMAINING=$((TIME_REMAINING-1))
    printf "${YELLOW}${MESSAGE}${WHITE}${TIME_REMAINING} \r"
    sleep 1
  done	

  printf "${NC}\n\n"

}


#
# MAIN SCRIPT
# ===========	
# 

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# NEED TO BE RAN WITH ADMIN PRIVILEGES
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

if [ "$EUID" -ne 0 ]
  then
    printf "\n${CYAN}This script needs to be ran with admin privileges to execute properly.\n"

  yes_or_no "${YELLOW}Would you like to run it again with the SUDO command?${NC}" "y"

  case $Y_N_ANSWER in
    [Yy]* ) printf "${NC}"; sudo ./archbangretroinstall.sh; exit;;
    [Nn]* ) printf "\n${CYAN}Bye bye...\n\n${NC}"; exit;;
  esac

fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# ENABLE ALL OUTPUTS TO BE SENT
# TO LOG.OUT DURING THE SCRIPT
# FOR DEBUGGING USAGE.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

echo ""
yes_or_no "Would you like to have the outputs into log.out?" "n"

if [ "$Y_N_ANSWER" == Y ]; then
  exec 3>&1 4>&2
  trap 'exec 2>&4 1>&3' 0 1 2 3
  exec 1>log.out 2>&1
fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# SHOW THE PARAMETERS ON SCREEN
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

clear
printf "\n\n${WHITE}ARCH LINUX INSTALL SCRIPT\n"
printf "=============================\n\n"
printf "${CYAN}Press Control-C to Cancel\n\n"
printf "${GREEN}FIRMWARE    = ${CYAN}${FIRMWARE}\n\n"
printf "${GREEN}TIMEZONE    = ${CYAN}${TIMEZONE}\n"
printf "${GREEN}REGION      = ${CYAN}${REGION}\n"
printf "${GREEN}LANGUAGE    = ${CYAN}${LANGUAGE}\n"
printf "${GREEN}KEYMAP      = ${CYAN}${KEYMAP}\n\n"
printf "${GREEN}HOSTNAME    = ${CYAN}${HOSTNAME}\n\n"
printf "${GREEN}ARCH_USER   = ${CYAN}${ARCH_USER}\n"
printf "${GREEN}USER_PSW    = ${CYAN}${USER_PSW}\n"
printf "${GREEN}ROOT_PSW    = ${CYAN}${ROOT_PSW}\n\n"
printf "${GREEN}MIRRORS COUNTRY = ${CYAN}${REFLECTOR_COUNTRY}\n\n"

printf "${RED}THIS WILL DESTROY ALL CONTENT OF ${WHITE}${BCK_RED}${DRIVE^^}${NC}${RED} !!!\n\n"

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# COUNTDOWN WARNING
# =================
# 
# This is needed to not only warn the HD will be 
# wiped, but for the install to work on slow hardware 
# as not all the services are started when the auto-login 
# occurs on the live CD, making this script fails when 
# launched too early.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

countsleep "Automatic install will start in... " 30 

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# INSTALL THE NEEDED DEPENDENCIES 
# TO RUN THIS SCRIPT FROM ARCH LIVE CD
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

pacman -Sy > /dev/null

if ! pacman -Qs dmidecode > /dev/null ; then
	pacman -S dmidecode --noconfirm > /dev/null
fi

if ! pacman -Qs reflector > /dev/null ; then
	pacman -S reflector --noconfirm > /dev/null
fi

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# ENABLE MIRRORS FROM $MIRROR_LINK
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

printf "${YELLOW}Setting up the best mirrors from ${REFLECTOR_COUNTRY} for this live session.\n\n${NC}" 

reflector --country "${REFLECTOR_COUNTRY}" --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacman -Sy > /dev/null

countsleep "Partitioning the disk will start in... " 5

# +-+-+-+-+-+-+-+-+-+-+-+-
# UPDATE THE SYSTEM CLOCK 
# +-+-+-+-+-+-+-+-+-+-+-+-

timedatectl set-ntp true

# +-+-+-+-+-+-+-+-+-+-
# PARTITION THE DISKS
# +-+-+-+-+-+-+-+-+-+-

make_swap_size

if mount | grep /mnt > /dev/null; then
  umount -R /mnt
fi 

wipefs -a $DRIVE 

if [ ${FIRMWARE} = "BIOS" ]; then
  parted -a optimal $DRIVE --script mklabel msdos
  parted -a optimal $DRIVE --script unit mib

  parted -a optimal $DRIVE --script mkpart primary 2048 3072
  parted -a optimal $DRIVE --script set 1 boot on

  parted -a optimal $DRIVE --script mkpart primary 3072 $SWAP_SIZE

  parted -a optimal $DRIVE --script mkpart primary $SWAP_SIZE -- -1

else
  parted -a optimal $DRIVE --script mklabel gpt
  parted -a optimal $DRIVE --script unit mib

  parted -a optimal $DRIVE --script mkpart primary 1 1025
  parted -a optimal $DRIVE --script name 1 boot
  parted -a optimal $DRIVE --script set 1 boot on

  parted -a optimal $DRIVE --script mkpart primary 1025 $SWAP_SIZE
  parted -a optimal $DRIVE --script name 2 swap

  parted -a optimal $DRIVE --script mkpart primary $SWAP_SIZE -- -1
  parted -a optimal $DRIVE --script name 3 rootfs

fi


# +-+-+-+-+-+-+-+-+-+-+-
# FORMAT THE PARTITIONS
# +-+-+-+-+-+-+-+-+-+-+-

if [ ${FIRMWARE} = "BIOS" ]; then
  yes | mkfs.ext2 ${DRIVE_PART1}
else
  yes | mkfs.fat -F32 ${DRIVE_PART1}
fi

yes | mkswap ${DRIVE_PART2}
yes | swapon ${DRIVE_PART2}
yes | mkfs.ext4 ${DRIVE_PART3}

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# MOUNT THE NEWLY CREATED PARTITIONS
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

mount /${DRIVE_PART3} /mnt
mkdir /mnt/boot
mount ${DRIVE_PART1} /mnt/boot

# +-+-+-+-+-+-+-+-+
# INSTALL PACKAGES
# +-+-+-+-+-+-+-+-+

EDITOR="vim"
DEPENDENCIES="git reflector net-tools moreutils"
NETWORK="iwd broadcom-wl"
OPENSSH="openssh"
OTHERS="neofetch"

pacstrap /mnt base base-devel linux linux-firmware man-db man-pages texinfo grub efibootmgr ${EDITOR} ${DEPENDENCIES} ${NETWORK} ${OPENSSH} ${OTHERS}

# +-+-+-+-+-+-+-+-+
# SETUP /ETC/FSTAB
# +-+-+-+-+-+-+-+-+

genfstab -U /mnt >> /mnt/etc/fstab

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-
# COPYING MIRRORLIST TO NEW INSTALLATION
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-

cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/

# +-+-+-+-+-+-+-
# CHROOT SCRIPT
# +-+-+-+-+-+-+-

arch-chroot /mnt /bin/bash << EOF

# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
# ENABLE MIRRORS FROM $MIRROR_LINK
# +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

printf "\n${YELLOW}Setting up the best mirrors from ${REFLECTOR_COUNTRY} for $HOSTNAME...\n\n${NC}"

reflector --country ${REFLECTOR_COUNTRY} --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

pacman -Sy > /dev/null

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


# +-+-+-+-+-+-+-+
# SETUP HOSTNAME
# +-+-+-+-+-+-+-+

printf "${HOSTNAME}" > /etc/hostname

# +-+-+-+-+-+-+-+-+
# SETUP /ETC/HOSTS
# +-+-+-+-+-+-+-+-+

printf "127.0.0.1       localhost\n" > /etc/hosts
printf "::1             localhost\n" >> /etc/hosts
printf "127.0.0.1       ${HOSTNAME}\n" >> /etc/hosts

# +-+-+-+-+-+-+-
# SETUP ROOT PASSWORD
# +-+-+-+-+-+-+-

echo "root:${ROOT_PSW}" | chpasswd

# +-+-+-+-+-+-+-+-+-+
# INSTALL BOOTLOADER
# +-+-+-+-+-+-+-+-+-+

if [ ${FIRMWARE} = "BIOS" ]; then
  grub-install --target=i386-pc ${DRIVE}
else
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
fi

grub-mkconfig -o /boot/grub/grub.cfg

# +-+-+-+-+-+-+-+-+-+-+-+-+-+
# VI --> VIM symbolink link.
# +-+-+-+-+-+-+-+-+-+-+-+-+-+

ln -s /usr/bin/vim /usr/bin/vi

# +-+-+-+-+-
# NETWORKING
# +-+-+-+-+-

systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service

cat > /etc/systemd/network/10-dhcp.network << "EOT"
[Match]
Name =*

[Network]
DHCP=ipv4
EOT

# +-+-+-+-+-+-+-+
# ENABLE OPENSSH
# +-+-+-+-+-+-+-+

systemctl enable sshd

# +-+-+-+-+-+-
# CREATE USER
# +-+-+-+-+-+-

useradd -m -G wheel -s /bin/bash $ARCH_USER

echo "${ARCH_USER}:${USER_PSW}" | chpasswd

sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# +-+-+-+-
# YAY-BIN
# +-+-+-+-

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/yay-bin.git
cd /home/${ARCH_USER}/yay-bin
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./yay-bin*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/yay-bin

# +-+-+-+-+-+-+-
# SHOWIPATLOGON
# +-+-+-+-+-+-+-

cd /home/${ARCH_USER}
sudo -u ${ARCH_USER} git clone https://aur.archlinux.org/showipatlogon.git
cd /home/${ARCH_USER}/showipatlogon
sudo -u ${ARCH_USER} makepkg -s
pacman -U ./showipatlogon*.pkg.tar.zst --noconfirm
rm -rf /home/${ARCH_USER}/showipatlogon

# +-+-+-+
# BASHRC
# +-+-+-+

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

EOF

echo
echo "INSTALLATION COMPLETED"
echo

#
# DONE
#


