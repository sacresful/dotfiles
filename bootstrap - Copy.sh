#!/bin/sh

# install bare minimum

install () {
	basestrap /mnt "$@"
}

# in live cd

# format drives and make partitions
lsblk
if [ ! -d "/sys/firmware/efi" ]; then
	sfdisk -n 1::+1G --typecode=1:ef02 
else
	sfdisk -n 1::+1G --typecode=1:ef00

sfdisk -n 2::+30G --typecode=2:8300
sfdisk -n 3::+
# make filesystems
if [ -d "/sys/firmware/efi" ]; then
	mkfs.fat -F32 -L BOOT /dev/$partition1
	fatlabel /dev/$partition1 ESP
else
mkfs.ext4 -L ROOT /dev/$partition2
mkfs.ext4 -L HOME /dev/$partition3
mkswap -L SWAP /dev/$partition4

# mounting drives
swapon /dev/disk/by-label/SWAP
mount /dev/disk/by-label/ROOT /mnt

# if home on separate partition
mkdir /mnt/home
mount /dev/disk-by-label/HOME /mnt/home

# mounting boot 
if [ -d "/sys/firmware/efi" ]; then
	mkdir /mnt/boot 				
	mount /dev/disk/by-label/BOOT /mnt/boot 
	mkdir /mnt/boot/efi
	mount /dev/disk/by-label/ESP /mnt/boot/efi
else
	mkdir /mnt/boot 				
	mount /dev/disk/by-label/BOOT /mnt/boot 

# install system
system=(
	base base-devel # base
	dinit elogind-dinit # init system
	linux linux-firmware # kernel
	grub # bootloader
	networkmanager networkmanager-dinit # access to network
	neovim vim # editors
	git
if [ -d "/sys/firmware/efi" ]; then
	efibootmgr # for efi systems
# todo: encrypted installation
	#cryptsetup lvm2 lvm2-dinit

# generate fstab - start drives after booting
fstabgen -L /mnt >> /mnt/etc/fstab

# get into actual system
artix-chroot /mnt bash

# set root password
while true
do
	read -p -s "Enter root password: " ROOTPASS
	if [ -z "$USERNAME"]; then
		echo "Username cannot be empty"
	else
		passwd "$ROOTPASS"
	fi
done

# create user
while true
do
	read -p "Enter username:" USERNAME
	
	if [ -z "$USERNAME"]; then
		echo "Username cannot be empty"
	else
		useradd -mG wheel "$USERNAME"
		echo "User '$USERNAME' has been created"
		break
	fi
done

# Set password for the user
while true
do
        read -p -s "Enter your new password: " PASSWORD1
        echo
        read -p -s "Re-enter your new password: " PASSWORD2
        echo

        if [ "$PASSWORD1" != "$PASSWORD2" ]; then
            echo "Passwords do not match. Please try again. "
        else
            echo -e "$PASSWORD1\n$PASSWORD1" | sudo passwd "$USERNAME"
            if [ $? -eq 0 ]; then
                echo "Password has been updated successfully. "
            else
                echo "Failed to update the password. "
            fi
            break
        fi
done

# sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# set hostname
while true
do
	read -p "Enter hostname: " HOSTNAME

	if [ -z "$HOSTNAME" ]; then
		echo "Enter valid hostname."
	else
		echo $HOSTNAME >> /etc/hostname
		break
	fi
done

# set default ips
echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        $HOSTNAME.localdomain  $HOSTNAME" >> /etc/hosts

# set timezone
while true
do
	read -p "Enter your region: " REGION
	if [ -f "/usr/share/zoneinfo/$REGION" ]; then
		ln -sf "/usr/share/zoneinfo/$REGION" /etc/localtime
		echo "Timezone set to $REGION."
		break
	elif [ -d "/usr/share/zoneinfo/$REGION" ]; then
		read -p "Enter your city:" CITY
		if [ -f "/usr/share/zoneinfo/$REGION/$CITY" ]; then
			ln -sf "/usr/share/zoneinfo/$REGION/$CITY" /etc/localtime
			echo "Timezone set to $REGION/$CITY"
			break
		else
			echo "Invalid city."
		fi
	else
		echo "Invalid region."
	fi
done

# generate locale
sed -i 's/^#pl_PL.UTF-8 UTF-8/pl_PL.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#pl_PL ISO-8859-2/pl_PL ISO-8859-2/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US ISO-8859-1/en_US ISO-8859-1/' /etc/locale.gen
locale-gen

#parallel downloading
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Enable arch remote repositories
pacman -Sy --noconfirm artix-archlinux-support

sed -i "/\[lib32]/,/Include'"'s/^#//' /etc/pacman.conf

echo "
# Arch
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf

# installing bootloader
if [ ! -d "/sys/firmware/efi" ]; then
	grub-install --recheck $drive
else
	pacman -S os-prober efibootmgr
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub /dev/disk/by-label/boot
fi

grub-mkconfig -o /boot/grub/grub.cfg

exit
reboot