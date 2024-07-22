#!/bin/sh

#-------------------------------------------------------------------------
#	  		Basic Setup
#-------------------------------------------------------------------------

LOGFILE=/home/artix/bootstrap.log
exec > >(tee -a "$LOGFILE") 2>&1

#-------------------------------------------------------------------------
#			Functions
#-------------------------------------------------------------------------

install () {
	basestrap /mnt "$@"
}

#-------------------------------------------------------------------------
#                        Installing Prerequisites
#-------------------------------------------------------------------------

pacman -S --noconfirm --needed gptfdisk parted pacman-contrib btrfs-progs

#-------------------------------------------------------------------------
#				Installation
#-------------------------------------------------------------------------

while true 
do
	read -rp "Encrypted installation? Y/N " TYPE
	case $TYPE in 
		[Yy][Ee][Ss]$ | [Yy])
			ENCRYPTED=true
			break
			;;
		[Nn][Oo]$ | [Nn])
			ENCRYPTED=false
			break
			;;
		*)
			echo "Please enter yes or no. "
			;;
	esac
done

#-------------------------------------------------------------------------
#			Formatting Drives
#-------------------------------------------------------------------------

lsblk -d -o NAME,SIZE,MODEL | grep -E "sd|nvme|vd"
while true 
do
	read -rp "Choose a drive to install linux on. " DRIVE
	if [ -b "/dev/$DRIVE" ]; then
		sgdisk -Z /dev/"$DRIVE"
		sgdisk -a 2048 -o /dev/"$DRIVE"
		if [ ! -d "/sys/firmware/efi" ]; then
			sgdisk -n 1::+1G --typecode=2:ef02 /dev/"$DRIVE"
		else
			sgdisk -n 1::+1G --typecode=2:ef00 /dev/"$DRIVE"
		fi
		sgdisk -n 2::-4G --typecode=3:8300 /dev/"$DRIVE"
		sgdisk -n 3::+4G --typecode=1:8200 /dev/"$DRIVE"
		break
	else
		echo "Invalid drive."
	fi
done
partprobe "${DRIVE}"

#-------------------------------------------------------------------------
#                    Creating Filesystems
#-------------------------------------------------------------------------


mkfs.fat -F32 /dev/"${DRIVE}"1
if [ "$ENCRYPTED" = true ]; then
	cryptsetup luksFormat /dev/"${DRIVE}"2
	cryptsetup open /dev/"${DRIVE}"2 cryptlvm
fi

while true
do

read -rp "Which filesystem: ext4 / btrfs? " FILESYSTEM 
	case $FILESYSTEM in
		ext4)
			if [ "$ENCRYPTED" = true ]; then
				mkfs.ext4 /dev/mapper/cryptlvm
			else
				mkfs.ext4 /dev/"${DRIVE}"2
			fi
			break
			;;
		btrfs)
			if [ "$ENCRYPTED" = true ]; then
				mkfs.btrfs /dev/mapper/cryptlvm
			else
				mkfs.btrfs /dev/"${DRIVE}"2
			fi
			break
			;;
	esac
done

mkswap /dev/"${DRIVE}"3

#-------------------------------------------------------------------------
#			Mounting Drives
#-------------------------------------------------------------------------

if [ "$ENCRYPTED" = true ]; then
	mount /dev/mapper/cryptlvm /mnt
else
	mount /dev/"${DRIVE}"2 /mnt
fi

if [ -d "/sys/firmware/efi" ]; then
	mkdir /mnt/boot 				
	mount /dev/disk/by-label/BOOT /mnt/boot 
	mkdir /mnt/boot/efi
	mount /dev/disk/by-label/ESP /mnt/boot/efi
else
	mkdir /mnt/boot 				
	mount /dev/"${DRIVE}"1 /mnt/boot 
fi

swapon /dev/"${DRIVE}"3

#-------------------------------------------------------------------------
#						Parrallel Downloads
#-------------------------------------------------------------------------

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

#-------------------------------------------------------------------------
#			Setting Up Mirrors
#-------------------------------------------------------------------------

#cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlistOG
#sed -i '/^## North America$/,/^##/!b;//d' "$MIRRORLIST_FILE"
echo "Generating mirror list"
rankmirrors -n 10 -m 0.5 /etc/pacman.d/mirrorlist | grep -i '^Server' > /etc/pacman.d/mymirrorlist
mv /etc/pacman.d/mirrorlist /etc/pacman.d/artixmirrorlist
mv /etc/pacman.d/mymirrorlist /etc/pacman.d/mirrorlist

#-------------------------------------------------------------------------
#			Installing Linux
#-------------------------------------------------------------------------

system=(
	base base-devel # base
	dinit elogind-dinit # init system
	linux linux-firmware # kernel
	grub # bootloader
	networkmanager networkmanager-dinit # access to network
	neovim vim # editors
	git
)
install "${system[@]}"

if [ -d "/sys/firmware/efi" ]; then
	basestrap /mnt efibootmgr # for efi systems
fi

if [ "$ENCRYPTED" = true ]; then
	basestrap /mnt cryptsetup lvm2 lvm2-dinit
fi


#-------------------------------------------------------------------------
#			Generating Fstab
#-------------------------------------------------------------------------

fstabgen -U /mnt >> /mnt/etc/fstab



#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
#						Installing Base System
#-------------------------------------------------------------------------
#-------------------------------------------------------------------------

while true
do
	read -rsp "Enter root password: " ROOTPASS
	echo
	if [ -z "$ROOTPASS" ]; then
		echo "Password cannot be empty"
	else
		read -rsp "Confirm root password: " ROOTPASS_CONFIRM
		echo
		if [ "$ROOTPASS" != "$ROOTPASS_CONFIRM" ]; then
			echo "Passwords do not match"
		else
			if [ $? -eq 0 ]; then
				break
			else
				echo "Failed to change password"
			fi
		fi
	fi
done

#-------------------------------------------------------------------------
#			Creating a User
#-------------------------------------------------------------------------

while true
do
	read -rp "Enter username: " USERNAME
	
	if [ -z "$USERNAME" ]; then
		echo "Username cannot be empty"
	else
		break
	fi
done

#-------------------------------------------------------------------------
#			Setting User's Password
#-------------------------------------------------------------------------

while true
do
	read -rsp "Enter user password: " PASS
	echo
	if [ -z "$PASS" ]; then
		echo "Password cannot be empty"
	else
		read -rsp "Confirm user password: " PASS_CONFIRM
		echo
		if [ "$PASS" != "$PASS_CONFIRM" ]; then
			echo "Passwords do not match"
		else
			if [ $? -eq 0 ]; then
				break
			else
				echo "Failed to change password"
			fi
		fi
	fi
done

#-------------------------------------------------------------------------
#			Set Hostname
#-------------------------------------------------------------------------

while true
do
	read -rp "Enter hostname: " SETHOSTNAME
	if [ -z "$SETHOSTNAME" ]; then
		echo "Enter valid hostname."
	else
		break
	fi
done

#-------------------------------------------------------------------------
#			Set Timezone
#-------------------------------------------------------------------------

while true
do
	read -rp "Enter your region: " REGION
	if [ -f "/usr/share/zoneinfo/$REGION" ]; then
		break
	elif [ -d "/usr/share/zoneinfo/$REGION" ]; then
		read -rp "Enter your city:" CITY
		if [ -f "/usr/share/zoneinfo/$REGION/$CITY" ]; then
			break
		else
			echo "Invalid city."
		fi
	else
		echo "Invalid region."
	fi
done

#-------------------------------------------------------------------------
#			      Choose where grub should be installed
#-------------------------------------------------------------------------


#lsblk -d -o NAME,SIZE,MODEL | grep -E "sd|nvme|vd"
#while true 
#do
#	read -rp "Choose a drive to install grub on. " DRIVE
#    break
#done

#-------------------------------------------------------------------------
#			      Chrooting into newly installed system
#-------------------------------------------------------------------------

artix-chroot /mnt << EOF &> "$LOGFILE"

echo "root:$ROOTPASS" | chpasswd

useradd -mG wheel "$USERNAME"
echo "$USERNAME:$PASS" | chpasswd

echo "$SETHOSTNAME" >> /etc/hostname

echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        $SETHOSTNAME.localdomain  $SETHOSTNAME" >> /etc/hosts

ln -sf "/usr/share/zoneinfo/$REGION" /etc/localtime
ln -sf "/usr/share/zoneinfo/$REGION/$CITY" /etc/localtime

#-------------------------------------------------------------------------
#			Sudo no Passowrd
#-------------------------------------------------------------------------

sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

#-------------------------------------------------------------------------
#			Generate Locale
#-------------------------------------------------------------------------

sed -i 's/^#pl_PL.UTF-8 UTF-8/pl_PL.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#pl_PL ISO-8859-2/pl_PL ISO-8859-2/' /etc/locale.gen
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^#en_US ISO-8859-1/en_US ISO-8859-1/' /etc/locale.gen
locale-gen

#-------------------------------------------------------------------------
#			Parallel Downloading
#-------------------------------------------------------------------------

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

#-------------------------------------------------------------------------
#			Setting up Mirrors
#-------------------------------------------------------------------------

pacman -Sy --noconfirm pacman-contrib
echo "Generating mirror list"
rankmirrors -n 10 -m 0.5 /etc/pacman.d/mirrorlist | grep -i '^Server' > /etc/pacman.d/mymirrorlist
mv /etc/pacman.d/mirrorlist /etc/pacman.d/artixmirrorlist
mv /etc/pacman.d/mymirrorlist /etc/pacman.d/mirrorlist

#-------------------------------------------------------------------------
#			Enable Arch Repositories
#-------------------------------------------------------------------------

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

#-------------------------------------------------------------------------
#			Encrypted Installation Features
#-------------------------------------------------------------------------

if [ "$ENCRYPTED" = true ]; then
	sed -i 's/filesystems/encrypt lvm2 filesystems/g' /etc/mkinitcpio.conf
	mkinitcpio -p linux
fi

if [ "$ENCRYPTED" = true ]; then
	ENCRYPTEDUUID=$(blkid | grep "^/dev/${DRIVE}3" | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')
	DECRYPTEDUUID=$(blkid | grep "^/dev/mapper/cryptlvm" | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')
	sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID=$ENCRYPTEDUUID:cryptlvm root=UUID=$DECRYPTEDUUID/" /etc/default/grub
	#sed -i "s|^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\(\"\)|\GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID="$ENCRYPTEDUUID":cryptlvm root=UUID="$DECRYPTEDUUID" \2|"" "/etc/default/grub"
fi

#-------------------------------------------------------------------------
#			Installing Bootloader
#-------------------------------------------------------------------------


if [ ! -d "/sys/firmware/efi" ]; then
	grub-install --recheck /dev/"$DRIVE"
else
	pacman -S os-prober efibootmgr
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub /dev/"$DRIVE"
fi

grub-mkconfig -o /boot/grub/grub.cfg

EOF

cp "$LOGFILE" /mnt/home/"$USERNAME"/bootstrap.log