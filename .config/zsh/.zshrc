# Colors
autoload -U colors && colors
PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%}@%{$fg[blue]%}%M %{$fg[magenta]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

# History

HISTFILE=~/.cache/zsh/history
HISTSIZE=100000000
SAVEHIST=100000000

# autocompletion
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.


# vi mode

bindkey -v
export KEYTIMEOUT=1

bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -v '^?' backward-delete-char

# colors
alias ls="ls -hN --color=auto --group-directories-first"
alias grep="grep --color=auto"

# aliases

alias vim="nvim"
alias p="sudo pacman"
alias df="df -h"
alias free="free -h"
alias sl="cd ~/.config/suckless/" 
alias scrot="scrot ~/pics/scrot/%d-%b-%Y_%H:%M.png"
alias kilall="killall"
alias nvidia-settings="nvidia-settings --config='$HOME/.config/nvidia/settings'"
alias zhistory="cat $HOME/.cache/zsh/history"
alias zcfg="cd ~/.config/zsh"
alias minecraft="minecraft-launcher --workDir $HOME/games/Minecraft"
alias minecraft-launcher="minecraft-launcher --workDir $HOME/games/Minecraft"
alias cleanup="sudo pacman -Rns $(pacman -Qtdq)"
alias yt-dlp="yt-dlp -f bestvideo+bestaudio"
alias lf="lfub"
alias dots="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
alias scripts="cd $HOME/.local/bin"
alias wps="cd $HOME/pics/wallpapers/"
alias xrdb="xrdb -l ~/.config/x11/xresources"
alias sxiv="nsxiv"
# Change cursor shape for different vi modes.
function zle-keymap-select () {
    case $KEYMAP in
        vicmd) echo -ne '\e[1 q';;      # block
        viins|main) echo -ne '\e[5 q';; # beam
    esac
}
zle -N zle-keymap-select
zle-line-init() {
    zle -K viins # initiate `vi insert` as keymap (can be removed if `bindkey -V` has been set elsewhere)
    echo -ne "\e[5 q"
}
zle -N zle-line-init
echo -ne '\e[5 q' # Use beam shape cursor on startup.
preexec() { echo -ne '\e[5 q' ;} # Use beam shape cursor for each new prompt.

ex ()
{
  if [ -f "$1" ] ; then
    case $1 in
      *.tar.bz2)   tar xjf $1   ;;
      *.tar.gz)    tar xzf $1   ;;
      *.bz2)       bunzip2 $1   ;;
      *.rar)       unrar x $1   ;;
      *.gz)        gunzip $1    ;;
      *.tar)       tar xf $1    ;;
      *.tbz2)      tar xjf $1   ;;
      *.tgz)       tar xzf $1   ;;
      *.zip)       unzip $1     ;;
      *.Z)         uncompress $1;;
      *.7z)        7z x $1      ;;
      *.deb)       ar x $1      ;;
      *.tar.xz)    tar xf $1    ;;
      *.tar.zst)   unzstd $1    ;;
      *)           echo "'$1' cannot be extracted via ex()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

#bind set completion-ignore-case on

# syntax highlighting
source ~/.config/zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
