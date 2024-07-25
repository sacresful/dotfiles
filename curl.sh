#!/bin/bash

# Checking if is running in Repo Folder
if [[ "$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')" =~ ^scripts$ ]]; then
    echo "You are running this in dotfiles folder."
    echo "Please use ./bootstrap.sh instead"
    exit
fi

# Installing git

echo "Installing git."
pacman -Sy --noconfirm --needed git glibc

echo "Cloning the repo"
git clone https://github.com/sacresful/dotfiles

echo "Executing bootstrap.sh"

cd $HOME/dotfiles

exec ./bootstrap.sh