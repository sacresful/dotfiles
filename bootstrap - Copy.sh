#!/bin/sh

# install bare minimum

install () {
	pacman -S --noconfirm "$@"
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
	basestrap /mnt 
	base base-devel # base
	dinit elogind-dinit # init system
	linux linux-firmware # kernel
	grub # bootloader
	networkmanager networkmanager-dinit # access to network
	neovim vim # editors
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
	read -p -s "Enter root password:" ROOTPASS
		passwd "$ROOTPASS"
done

# installing bootloader
if [ ! -d "/sys/firmware/efi" ]; then
	grub-install --recheck $drive
else
	pacman -S os-prober efibootmgr
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub /dev/disk/by-label/boot
fi

grub-mkconfig -o /boot/grub/grub.cfg
