#!/bin/sh

# install bare minimum

LOGFILE=/home/artix/bootstrap.log
exec > >(tee -a "$LOGFILE") 2>&1

install () {
	basestrap /mnt "$@"
}

pacman -S --noconfirm gptfdisk parted	

while true 
do
	read -p "Encrypted installation? Y/N " TYPE
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

# Format drives, create partitions.
lsblk -d -o NAME,SIZE,MODEL | grep -E "sd|nvme|vd"
while true 
do
	read -p "Choose a drive to install linux on. " DRIVE
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
partprobe ${DRIVE}

# make filesystems
mkswap /dev/${DRIVE}1
mkfs.fat -F32 /dev/${DRIVE}2
if [ "$ENCRYPTED" = true ]; then
	cryptsetup luksFormat /dev/${DRIVE}3
	cryptsetup open /dev/${DRIVE}3 cryptlvm
fi

while true
do

read -p "Which filesystem: ext4 / btrfs? " FILESYSTEM 
	case $FILESYSTEM in
		ext4)
			if [ "$ENCRYPTED" = true ]; then
				mkfs.ext4 /dev/mapper/cryptlvm
			else
				mkfs.ext4 /dev/${DRIVE}3
			fi
			break
			;;
		btrfs)
			if [ "$ENCRYPTED" = true ]; then
				mkfs.btrfs /dev/mapper/cryptlvm
			else
				mkfs.btrfs /dev/${DRIVE}3
			fi
			break
			;;
	esac
done


# mounting drives
swapon /dev/${DRIVE}1
if [ "$ENCRYPTED" = true ]; then
	mount /dev/mapper/cryptlvm /mnt
else
	mount /dev/${DRIVE}3 /mnt
fi
# mounting boot 
if [ -d "/sys/firmware/efi" ]; then
	mkdir /mnt/boot 				
	mount /dev/disk/by-label/BOOT /mnt/boot 
	mkdir /mnt/boot/efi
	mount /dev/disk/by-label/ESP /mnt/boot/efi
else
	mkdir /mnt/boot 				
	mount /dev/${DRIVE}2 /mnt/boot 
fi

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

#MIRRORS
while true
do
	read -p "Enter your location (e.g., Country/City): " LOCATION
	
	if [ -z "$LOCATION" ]; then
        echo "No location provided. Please try again."
        continue
    fi

    START_LINE=$(grep -n "^# ${LOCATION}" "$MIRRORLIST" | head -n 1 | cut -d: -f1)

    if [ -z "$START_LINE" ]; then
        echo "Location not found. Please try again."
        continue
    fi

    END_LINE=$(awk "NR > $START_LINE" "$MIRRORLIST" | grep -n "^#" | head -n 1 | cut -d: -f1)
    if [ -z "$END_LINE" ]; then
        END_LINE=$(wc -l < "$MIRRORLIST")
    else
        END_LINE=$((START_LINE + END_LINE - 1))
    fi

    EXTRACTED_SECTION=$(sed -n "${START_LINE},${END_LINE}p" "$MIRRORLIST")

    # Remove existing mirrors below the `# Default mirrors` section
    awk "/^# Default mirrors/{flag=1; next}/^#/{flag=0}flag" "$MIRRORLIST" > "$MIRRORLIST.tmp"
    mv "$MIRRORLIST.tmp" "$MIRRORLIST"

    # Insert the extracted section above the `# Default mirrors` section
    sed -i "/^# Default mirrors/i $EXTRACTED_SECTION" "$MIRRORLIST"

    echo "Mirrorlist updated successfully."
    break
	
#	START_LINE=$(grep -n "^# ${location}" "$MIRRORLIST" | head -n 1 | cut -d: -f1)
#    if [ -z "$START_LINE" ]; then
#        return 1
#    fi
#	
#	END_LINE=$(awk "NR > $START_LINE" "$MIRRORLIST" | grep -n "^#" | head -n 1 | cut -d: -f1)
 #   if [ -z "$END_LINE" ]; then
#        END_LINE=$(wc -l < "$MIRRORLIST")
#    else
#        END_LINE=$((START_LINE + END_LINE - 1))
 #   fi
#	
#	EXTRACTED_SECTION=$(sed -n "${START_LINE},${END_LINE}p" "$MIRRORLIST")
#    awk "/^# Default mirrors/{flag=1; next}/^#/{flag=0}flag" "$MIRRORLIST" > "$MIRRORLIST.tmp"
 #   mv "$MIRRORLIST.tmp" "$MIRRORLIST"
 #   sed -i "/^# Default mirrors/i $EXTRACTED_SECTION" "$MIRRORLIST"
	
done

#/etc/pacman.d/mirrorlist 

# install system
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


# generate fstab - start drives after booting
fstabgen -U /mnt >> /mnt/etc/fstab

# get into actual system
artix-chroot /mnt bash

# set root password
while true
do
	read -p -s "Enter root password: " ROOTPASS
	if [ -z "$ROOTPASS" ]; then
		echo "Password cannot be empty"
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
		echo "$HOSTNAME" >> /etc/hostname
		break
	fi
done

# set default ips
echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        "$HOSTNAME".localdomain  "$HOSTNAME"" >> /etc/hosts

# set timezone
while true
do
	read -p "Enter your region: " REGION
	if [ -f "/usr/share/zoneinfo/"$REGION"" ]; then
		ln -sf "/usr/share/zoneinfo/"$REGION"" /etc/localtime
		echo "Timezone set to "$REGION"."
		break
	elif [ -d "/usr/share/zoneinfo/"$REGION"" ]; then
		read -p "Enter your city:" CITY
		if [ -f "/usr/share/zoneinfo/"$REGION"/"$CITY"" ]; then
			ln -sf "/usr/share/zoneinfo/"$REGION"/"$CITY"" /etc/localtime
			echo "Timezone set to "$REGION"/"$CITY""
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

if [ "$ENCRYPTED" = true ]; then
	sed -i '/^HOOKS=/ {s/"\(.*\)"/"\1 crypt lvm2"/}' "/etc/mkinitcpio.conf"
	mkinitcpio -p linux
fi

$ENCRYPTEDUUID=blkid | grep '^/dev/${DRIVE}3' | sed -n 's/.*UUID="\([^"]*\)".*/\1/p'
$DECRYPTEDUUID=blkid | grep '^/dev/mapper/cryptlvm' | sed -n 's/.*UUID="\([^"]*\)".*/\1/p'


sed -i "s|^\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\(\"\)|\GRUB_CMDLINE_LINUX_DEFAULT="quiet splash cryptdevice=UUID="$ENCRYPTEDUUID":cryptlvm root=UUID="$DECRYPTEDUUID" \2|"" "/etc/default/grub"
#/etc/default/grub
#GRUB_CMDLINE_LINUX_DEFAULT:
##cryptdevice=UUID=$ENCRYPTEDUUID:cryptlvm 
#root=UUID=$DECRYPTEDUUID


# installing bootloader
if [ ! -d "/sys/firmware/efi" ]; then
	grub-install --recheck /dev/"$DRIVE"
else
	pacman -S os-prober efibootmgr
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub /dev/"$DRIVE"
fi

grub-mkconfig -o /boot/grub/grub.cfg


exit
cp "$LOGFILE" /home/"$USERNAME"/
reboot