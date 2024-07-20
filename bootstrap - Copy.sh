#!/bin/sh

# install bare minimum

install () {
	basestrap /mnt "$@"
}

# in live cd

pacman -S gptfdisk

while true 
do
	read -p "Installation type: normal or encrypted? " INSTALL_TYPE
	break
done

select_option() {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "$2   $1 "; }
    print_selected()   { printf "$2  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    get_cursor_col()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${COL#*[}; }
    key_input()         {
                        local key
                        IFS= read -rsn1 key 2>/dev/null >&2
                        if [[ $key = ""      ]]; then echo enter; fi;
                        if [[ $key = $'\x20' ]]; then echo space; fi;
                        if [[ $key = "k" ]]; then echo up; fi;
                        if [[ $key = "j" ]]; then echo down; fi;
                        if [[ $key = "h" ]]; then echo left; fi;
                        if [[ $key = "l" ]]; then echo right; fi;
                        if [[ $key = "a" ]]; then echo all; fi;
                        if [[ $key = "n" ]]; then echo none; fi;
                        if [[ $key = $'\x1b' ]]; then
                            read -rsn2 key
                            if [[ $key = [A || $key = k ]]; then echo up;    fi;
                            if [[ $key = [B || $key = j ]]; then echo down;  fi;
                            if [[ $key = [C || $key = l ]]; then echo right;  fi;
                            if [[ $key = [D || $key = h ]]; then echo left;  fi;
                        fi 
    }
    print_options_multicol() {
        # print options by overwriting the last lines
        local curr_col=$1
        local curr_row=$2
        local curr_idx=0

        local idx=0
        local row=0
        local col=0
        
        curr_idx=$(( $curr_col + $curr_row * $colmax ))
        
        for option in "${options[@]}"; do

            row=$(( $idx/$colmax ))
            col=$(( $idx - $row * $colmax ))

            cursor_to $(( $startrow + $row + 1)) $(( $offset * $col + 1))
            if [ $idx -eq $curr_idx ]; then
                print_selected "$option"
            else
                print_option "$option"
            fi
            ((idx++))
        done
    }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local return_value=$1
    local lastrow=`get_cursor_row`
    local lastcol=`get_cursor_col`
    local startrow=$(($lastrow - $#))
    local startcol=1
    local lines=$( tput lines )
    local cols=$( tput cols ) 
    local colmax=$2
    local offset=$(( $cols / $colmax ))

    local size=$4
    shift 4

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local active_row=0
    local active_col=0
    while true; do
        print_options_multicol $active_col $active_row 
        # user key control
        case `key_input` in
            enter)  break;;
            up)     ((active_row--));
                    if [ $active_row -lt 0 ]; then active_row=0; fi;;
            down)   ((active_row++));
                    if [ $active_row -ge $(( ${#options[@]} / $colmax ))  ]; then active_row=$(( ${#options[@]} / $colmax )); fi;;
            left)     ((active_col=$active_col - 1));
                    if [ $active_col -lt 0 ]; then active_col=0; fi;;
            right)     ((active_col=$active_col + 1));
                    if [ $active_col -ge $colmax ]; then active_col=$(( $colmax - 1 )) ; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $(( $active_col + $active_row * $colmax ))
}

diskpart () {
echo -ne "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formating your disk there is no way to get data back
------------------------------------------------------------------------

"

PS3='
Select the disk to install on: '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option $? 1 "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} selected \n"
    set_option DISK ${disk%|*}

drivessd
}

diskpart

# format drives and make partitions
lsblk
sgdisk -Z ${DISK}
sgdisk -a 2048 -o ${DISK}

sgdisk -n 1::+4G --typecode=1:8200 ${DISK}
if [ ! -d "/sys/firmware/efi" ]; then
	sgdisk -n 2::+1G --typecode=2:ef02 ${DISK}
else
	sgdisk -n 2::+1G --typecode=2:ef00 ${DISK}

sgdisk -n 3::-0 --typecode=3:8300 ${DISK}

fi

if [ $INSTALL_TYPE == encrypted ]; then
	cryptsetup luksFormat /dev/$partition3
	cryptsetup open /dev/$partition3 cryptlvm
fi
# make filesystems
mkswap /dev/$partition1
mkfs.fat -F32 /dev/$partition2
if [ $INSTALL_TYPE == encrypted ]; then
	mkfs.ext4 /dev/mapper/cryptlvm
else
	mkfs.ext4 /dev/$partition3
fi


# mounting drives
swapon /dev/$partition1
if [ $INSTALL_TYPE == encrypted ]; then
	mount /dev/mapper/cryptlvm /mnt
else
	mount /dev/$partition3 /mnt
fi

# mounting boot 
if [ -d "/sys/firmware/efi" ]; then
	mkdir /mnt/boot 				
	mount /dev/disk/by-label/BOOT /mnt/boot 
	mkdir /mnt/boot/efi
	mount /dev/disk/by-label/ESP /mnt/boot/efi
else
	mkdir /mnt/boot 				
	mount /dev/$partition1 /mnt/boot 
fi
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

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
install "{system[@]}"

if [ -d "/sys/firmware/efi" ]; then
	basestrap /mnt efibootmgr # for efi systems
fi
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