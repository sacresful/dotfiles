export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XINITRC="$XDG_CONFIG_HOME/x11/xinitrc"
export _JAVA_OPTIONS=-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java
export PASSWORD_STORE_DIR="$XDG_DATA_HOME"/pass
export GNUPGHOME="$XDG_DATA_HOME"/gnupg
#export XAUTHORITY="$XDG_RUNTIME_DIR"/Xauthority
export CARGO_HOME="$XDG_DATA_HOME"/cargo

export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:$HOME/.local/bin/statusbar
export PATH=$PATH:$HOME/.local/bin/cronjobs
export PATH=$PATH:$HOME/.local/bin/xdg-ninja
export PATH=$PATH:/usr/bin

export EDITOR="nvim"
export TERMINAL="st"
export BROWSER="firefox"
export READER="zathura"

export AWT_TOOLKIT="MToolkit wmname LG3D" # wmname
export _JAVA_AWT_WM_NONREPARENTING=1 # fix for java programs
export MOZ_USE_XINPUT2="1"
export WINEPREFIX="$XDG_DATA_HOME"/wine

