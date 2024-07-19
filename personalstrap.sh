
# SYSTEM CONFIGURATION

install () {
	pacman -S --noconfirm "$@"
}

sudo dinitctl enable NetworkManager

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

# set password for user
while true
do
	read -p -s "Enter password:" PASSWORD1
	
	if [ -z "$PASSWORD1" ]; then
		echo "Password cannot be empty"
	else
		read -p -s "Re-enter password:" PASSWORD2	 
			if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
       		 		set_option "$1" "$PASSWORD1"
    			else
        			echo -ne "ERROR! Passwords do not match. \n"
        			set_password
    			fi
done

# set hostname
while true
do
	read -p "Enter hostname:" HOSTNAME

	if [ -z "$HOSTNAME" ]; then
		echo "Enter valid hostname"
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
	read -p "Enter your region:" TIMEZONE
	if [ -f TIMEZONE ]; then
		ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
		break
	elif [ -d TIMEZONE ]; then
		read -p "Enter your city:" CITY
		ln -sf /usr/share/zoneinfo/"$TIMEZONE"/"$CITY" /etc/localtime
		break
	fi
done

# generate locale
while true
do
	read -p "Which locale: pl or en" LOCALE
		if LOCALE = pl
			sed -i 's/^#pl_PL.UTF-8 UTF-8/pl_PL.UTF-8 UTF-8/' /etc/locale.gen
			sed -i 's/^#pl_PL ISO-8859-2/pl_PL ISO-8859-2/' /etc/locale.gen
		elif LOCALE = en
			sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
			sed -i 's/^#en_US ISO-8859-1/en_US ISO-8859-1/' /etc/locale.gen
		fi
	locale-gen
done

#parallel downloading
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Graphic env
pacman -S --noconfirm xorg xorg-xinit xorg-xrandr

# Enable arch remote repositories
pacman -S --noconfirm artix-archlinux-support

sed -i "/\[lib32]/,/Include'"'s/^#//' /etc/pacman.conf

sudo echo "
# Arch
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf

# audio 
audio_programs=(
"pipewire"
"pipewire-audio"
"pipewire-alsa"
"pipewire-pulse"
"pipewire-jack"
"wireplumber"
"pulsemixer"
)

install "${audio_programs[@]}"

# some fonts
fonts=(
noto-fonts
noto-fonts-cjk
noto-fonts-emoji
)

install "${fonts[@]}"

# sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

######################################### PERSONAL #####################################


mkdirs () {
	mkdir "$@"
}
dirs=(
	"desktop"
	"docs"
	"pics"
	"dl"
	"music"
	"repos"
	"vids"
	"games"
	"docs/templates"
	"docs/public"
)
mkdirs "${dirs[@]}"

# check this later
#if [[ ${FS} == "luks" ]]; then
# Making sure to edit mkinitcpio conf if luks is selected
# add encrypt in mkinitcpio.conf before filesystems in hooks
#    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
# making mkinitcpio with linux kernel
#    mkinitcpio -p linux
#fi

# install gpu drivers
#gpu_type=$(lspci)
#if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
#    pacman -S --noconfirm --needed nvidia
#	nvidia-xconfig

#elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
 #   pacman -S --noconfirm --needed xf86-video-amdgpu

#elif grep -E "Integrated Graphics Controller" <<< ${gpu_type}; then
 #   pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa

#elif grep -E "Intel Corporation UHD" <<< ${gpu_type}; then
 #   pacman -S --needed --noconfirm libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
#fi

apps=(
	"zsh" # main shell
	"dash" # shell #2
	"man-db" # manuals
	"firefox" # browser
	"lf" # filemanager
	"zip" # zip
	"unzip" # unzip
	"wget"	# wget
	"ntfs-3g"	# mount ntfs drives
	"scrot" # screenshoter
	"x264" # codec
	"x265" # codec
	"ffmpeg" # ffmpeg
	"mediainfo" # properties
	"calcurse"	# calendar
	"xclip" # clipboard
	"redshift" # blue light filter
	"unclutter" # remove mouse from screen 
	"plocate" # search engine for linux
	"cups" 
	"cups-dinit"	# printer server
	"mpv" # videoplayer
	"zathura" # pdf reader
	"zathura-pdf-poppler" # pdf reader
	"obs-studio"	# recording soft
	"wmname"	# window manager name, fixes java stuff
	"imagemagick" # image editor
	"gimp" # image editor
	"xwallpaper" # set wallpaper
	"xcompmgr"	# compositor
	"cronie"
	"cronie-dinit" # cronjob handler
	"python-pywal" # pywal, generating color schemes
	"xdg-desktop-portal"	# allows opening external apps
	"wine" # wine ig
	"pass" # password manager
	"dunst" # notify service
	"nsxiv" # image viewer
	"steam" # steam/games
	"neofetch" # neofetch
	"discord"	# discord
	"inetutils" # ftp
	"ufw" 
	"ufw-dinit"	# firewall
	"openssh" # ssh
	"rsync" # transfering files using ssh
	"yt-dlp" # youtube download
	"glow" # things for xdg ninja 
	"jq" # things for xdg ninja
	"samba" # file sharing
	"avahi" # samba dependency
	"nfs-utils" # something for ntfs drives
	"mpd" # music daemon
	"ncmpcpp" # music player
	"udev" # usb device listening
	"xdg-user-dirs" # default folders
	# laptop stuff
	#tlp
	#powertop
	#ethtool
	# net tools maybe
)

install "${apps[@]}"

xdg-user-dirs-update

# install virtualization
#sudo pacman -S
#qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libvirt libvirt-dinit 
#sudo usermod -aG libvirt

#cd repos
#git clone https://aur.archlinux.org/yay.git
#cd yay
#makepkg -si

#yay ookla-speedtest-bin # speedtest
#yay ueberzugpp # ueberzug

#setup firewall default conf
sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw allow CIFS
#Samba conf
sudo ufw app update Samba
sudo echo "[Samba]
title=LanManager-like file and printer server for Unix
description=The Samba software suite is a collection of programs that implements the SMB/CIFS protocol for unix systems, allowing you to serve files and printers to Windows, NT, OS/2 and DOS clients. This protocol is sometimes also referred to as the LanManager or NetBIOS protocol.
ports=137,138/udp|139,445/tcp" >> /etc/ufw/applications.d/samba
sudo allow Samba
sudo ufw allow 4000/tcp
sudo ufw allow 6112/tcp

# make dash the default shell for shell scripts
ln -sf /usr/bin/dash /bin/sh

# make zsh default shell for terminal 
sudo echo "export ZDOTDIR="$HOME"/.config/zsh" >> /etc/zsh/zshenv
chsh -s /bin/zsh sacresful

# Enable Services
sudo dinitctl enable ufw
sudo dinitctl enable cupsd
sudo dinitctl enable cronie
sudo dinitctl enable sshd
sudo dinitctl enable libvirtd
# if laptop setting
sudo dinitctl enable tlp

# get config files

cp -R dotfiles/.config .
cp -R dotfiles/.local .

cd ~/.config/suckless/dwm
sudo make install
cd ..
cd dmenu
sudo make install
cd ..
cd dwmblocks
sudo make install
cd ..
cd st
sudo make install
cd
# autologin
sed -i "s/agetty --noclear/agetty -a $(whoami) --noclear/" /etc/dinit.d/tty1