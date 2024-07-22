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
		sgdisk -n 1::+4G --typecode=1:8200 /dev/"$DRIVE"
		if [ ! -d "/sys/firmware/efi" ]; then
			sgdisk -n 2::+1G --typecode=2:ef02 /dev/"$DRIVE"
		else
			sgdisk -n 2::+1G --typecode=2:ef00 /dev/"$DRIVE"
		fi
		sgdisk -n 3::-0 --typecode=3:8300 /dev/"$DRIVE"
		break
	else
		echo "Invalid drive."
	fi
done
partprobe "${DRIVE}"

#-------------------------------------------------------------------------
#                    Creating Filesystems
#-------------------------------------------------------------------------

mkswap /dev/"${DRIVE}"1
mkfs.fat -F32 /dev/"${DRIVE}"2
if [ "$ENCRYPTED" = true ]; then
	cryptsetup luksFormat /dev/"${DRIVE}"3
	cryptsetup open /dev/"${DRIVE}"3 cryptlvm
fi

while true
do

read -rp "Which filesystem: ext4 / btrfs? " FILESYSTEM 
	case $FILESYSTEM in
		ext4)
			if [ "$ENCRYPTED" = true ]; then
				mkfs.ext4 /dev/mapper/cryptlvm
			else
				mkfs.ext4 /dev/"${DRIVE}"3
			fi
			break
			;;
		btrfs)
			if [ "$ENCRYPTED" = true ]; then
				mkfs.btrfs /dev/mapper/cryptlvm
			else
				mkfs.btrfs /dev/"${DRIVE}"3
			fi
			break
			;;
	esac
done

#-------------------------------------------------------------------------
#			Mounting Drives
#-------------------------------------------------------------------------

swapon /dev/"${DRIVE}"1
if [ "$ENCRYPTED" = true ]; then
	mount /dev/mapper/cryptlvm /mnt
else
	mount /dev/"${DRIVE}"3 /mnt
fi

if [ -d "/sys/firmware/efi" ]; then
	mkdir /mnt/boot 				
	mount /dev/disk/by-label/BOOT /mnt/boot 
	mkdir /mnt/boot/efi
	mount /dev/disk/by-label/ESP /mnt/boot/efi
else
	mkdir /mnt/boot 				
	mount /dev/"${DRIVE}"2 /mnt/boot 
fi

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
#			Installing Base System
#-------------------------------------------------------------------------

artix-chroot /mnt  << EOF
cd /root
git clone https://github.com/sacresful/dotfiles
./Artixstrap.sh
EOF

cp "$LOGFILE" /mnt/home/"$USERNAME"/boostrap.log