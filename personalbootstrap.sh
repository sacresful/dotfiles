#!/bin/sh

#-------------------------------------------------------------------------
# Basic Setup
#-------------------------------------------------------------------------

LOGFILE=/home/$(whoami)/personalbootstrap.log
exec > >(tee -a "$LOGFILE") 2>&1

install () {
	sudo pacman -S --noconfirm "$@"
}

sudo dinitctl enable NetworkManager

while true; do
if ping -c 3 8.8.8.8 &> /dev/null; then
	echo "Connected to internet"
	break
else
	echo "No connection to internet"
	exit 1
done

#-------------------------------------------------------------------------
# Graphic Environment	
#-------------------------------------------------------------------------

sudo pacman -Sy --noconfirm xorg xorg-xinit xorg-xrandr

#-------------------------------------------------------------------------
# Graphic Drivers	
#-------------------------------------------------------------------------

gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<< "${gpu_type}"; then
    sudo pacman -S --noconfirm --needed nvidia
	nvidia-xconfig
elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
    sudo pacman -S --noconfirm --needed xf86-video-amdgpu
elif grep -E "Integrated Graphics Controller" <<< "${gpu_type}"; then
    sudo pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif grep -E "Intel Corporation UHD" <<< "${gpu_type}"; then
    sudo pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
fi

#-------------------------------------------------------------------------
# Audio	
#-------------------------------------------------------------------------

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

#-------------------------------------------------------------------------
# Fonts	
#-------------------------------------------------------------------------

fonts=(
	"noto-fonts"
	"noto-fonts-cjk"
	"noto-fonts-emoji"
)

install "${fonts[@]}"

#-------------------------------------------------------------------------
# Autologin	
#-------------------------------------------------------------------------

sudo sed -i "s/agetty --noclear/agetty -a $(whoami) --noclear/" /etc/dinit.d/tty1

#-------------------------------------------------------------------------
# Personal Setup		
#-------------------------------------------------------------------------

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
	"fastfetch" # fastfetch
	"discord"	# discord
	"inetutils" # ftp
	"ufw" 
	"ufw-dinit"	# firewall
	"openssh"
	"openssh-dinit" # ssh
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
	"tlp"
	"tlp-dinit"
	"powertop"
	"ethtool"
	# net tools maybe
)

install "${apps[@]}"

#cd /home/($whoami)/
#rm -rf Downloads Music Public Templates Videos Documents Desktop Pictures

#-------------------------------------------------------------------------
# Virtualization		
#-------------------------------------------------------------------------

sudo pacman -S --noconfirm qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libvirt libvirt-dinit 
sudo usermod -aG libvirt $(whoami)

#-------------------------------------------------------------------------
# Firewall Setup		
#-------------------------------------------------------------------------

sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw allow CIFS
sudo ufw app update Samba
sudo echo "[Samba]
title=LanManager-like file and printer server for Unix
description=The Samba software suite is a collection of programs that implements the SMB/CIFS protocol for unix systems, allowing you to serve files and printers to Windows, NT, OS/2 and DOS clients. This protocol is sometimes also referred to as the LanManager or NetBIOS protocol.
ports=137,138/udp|139,445/tcp" | sudo tee -a /etc/ufw/applications.d/samba > /dev/null
sudo ufw allow Samba
sudo ufw allow 4000/tcp
sudo ufw allow 6112/tcp

#-------------------------------------------------------------------------
# Enable Services		
#-------------------------------------------------------------------------

sudo dinitctl enable ufw
sudo dinitctl enable cupsd
sudo dinitctl enable cronie
sudo dinitctl enable sshd
sudo dinitctl enable libvirtd
sudo dinitctl enable tlp

#-------------------------------------------------------------------------
# Install AUR Helper		
#-------------------------------------------------------------------------

cd repos || exit
git clone https://aur.archlinux.org/paru.git /home/$(whoami)/repos/paru
cd paru || exit
makepkg -si

paru -S --noconfirm xdg-ninja

#yay ookla-speedtest-bin # speedtest
#yay ueberzugpp # ueberzug

#-------------------------------------------------------------------------
# Set the default shell to dash 
#-------------------------------------------------------------------------

sudo ln -sf /usr/bin/dash /bin/sh

#-------------------------------------------------------------------------
# Set the default termial shell to zsh 
#-------------------------------------------------------------------------

echo "export ZDOTDIR=/home/$(whoami)/.config/zsh" | sudo tee -a /etc/zsh/zshenv > /dev/null
chsh -s /bin/zsh $(whoami)

#-------------------------------------------------------------------------
# Get the desktop environment files 
#-------------------------------------------------------------------------
rm -rf /home/$(whoami)/.bash_logout				
rm -rf /home/$(whoami)/.bash_profile
rm -rf /home/$(whoami)/.bashrc	
cp -R /home/$(whoami)/dotfiles/.config /home/$(whoami)/
cp -R /home/$(whoami)/dotfiles/.local /home/$(whoami)/

xdg-user-dirs-update

cd /home/$(whoami)/.config/suckless/dwm || exit
sudo make install
cd .. 
cd dmenu || exit
sudo make install
cd ..
cd dwmblocks || exit
sudo make install
cd ..
cd st || exit
sudo make install
cd || exit

rm -rf /home/$(whoami)/dotfiles			

exit																