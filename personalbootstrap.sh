#!/bin/sh

#-------------------------------------------------------------------------
#							Basic Setup
#-------------------------------------------------------------------------

LOGFILE=/root/personalbootstrap.log
exec > >(tee -a "$LOGFILE") 2>&1

install () {
	sudo pacman -S --noconfirm "$@"
}

sudo dinitctl enable NetworkManager

#-------------------------------------------------------------------------
#						  Graphic Environment	
#-------------------------------------------------------------------------

pacman -Sy --noconfirm xorg xorg-xinit xorg-xrandr

#-------------------------------------------------------------------------
#						   Graphic Drivers	
#-------------------------------------------------------------------------

gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<< "${gpu_type}"; then
    pacman -S --noconfirm --needed nvidia
	nvidia-xconfig
elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif grep -E "Integrated Graphics Controller" <<< "${gpu_type}"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif grep -E "Intel Corporation UHD" <<< "${gpu_type}"; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
fi

#-------------------------------------------------------------------------
#			  					Audio	
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
#			   					Fonts	
#-------------------------------------------------------------------------

fonts=(
	"noto-fonts"
	"noto-fonts-cjk"
	"noto-fonts-emoji"
)

install "${fonts[@]}"

#-------------------------------------------------------------------------
#			   				  Autologin	
#-------------------------------------------------------------------------

sed -i "s/agetty --noclear/agetty -a $(whoami) --noclear/" /etc/dinit.d/tty1

#-------------------------------------------------------------------------
#			   				Personal Setup		
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

xdg-user-dirs-update

#-------------------------------------------------------------------------
#			   Virtualization		
#-------------------------------------------------------------------------

pacman -S --noconfirm qemu virt-manager virt-viewer dnsmasq vde2 bridge-utils openbsd-netcat libvirt libvirt-dinit 
usermod -aG libvirt

#-------------------------------------------------------------------------
#			   Firewall Setup		
#-------------------------------------------------------------------------

ufw limit 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
ufw enable
ufw allow CIFS
ufw app update Samba
echo "[Samba]
title=LanManager-like file and printer server for Unix
description=The Samba software suite is a collection of programs that implements the SMB/CIFS protocol for unix systems, allowing you to serve files and printers to Windows, NT, OS/2 and DOS clients. This protocol is sometimes also referred to as the LanManager or NetBIOS protocol.
ports=137,138/udp|139,445/tcp" >> /etc/ufw/applications.d/samba
ufw allow Samba
ufw allow 4000/tcp
ufw allow 6112/tcp

#-------------------------------------------------------------------------
#			   Enable Services		
#-------------------------------------------------------------------------

dinitctl enable ufw
dinitctl enable cupsd
dinitctl enable cronie
dinitctl enable sshd
dinitctl enable libvirtd
dinitctl enable tlp

#-------------------------------------------------------------------------
#			  Install AUR Helper		
#-------------------------------------------------------------------------

cd repos || exit
git clone https://aur.archlinux.org/paru.git
cd paru || exit
makepkg -si

#yay ookla-speedtest-bin # speedtest
#yay ueberzugpp # ueberzug

#-------------------------------------------------------------------------
#		 Set the default shell to dash 
#-------------------------------------------------------------------------

ln -sf /usr/bin/dash /bin/sh

#-------------------------------------------------------------------------
#		 Set the default termial shell to zsh 
#-------------------------------------------------------------------------

echo "export ZDOTDIR=$HOME/.config/zsh" | sudo tee -a /etc/zsh/zshenv > /dev/null
chsh -s /bin/zsh sacresful

#-------------------------------------------------------------------------
#		 	Get the desktop environment files 
#-------------------------------------------------------------------------

cp -R /root/dotfiles/.config /home/"$USERNAME"/
cp -R /root/dotfiles/.local /home/"$USERNAME"/

cd /home/"$USERNAME"/.config/suckless/dwm || exit
make install
cd .. 
cd dmenu || exit
make install
cd ..
cd dwmblocks || exit
make install
cd ..
cd st || exit
make install
cd || exit

rm -rf /home/"$USERNAME"/*																																														
	
sudo cp "$LOGFILE" /home/"$USERNAME"/personalbootstrap.log