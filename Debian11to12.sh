#!/bin/bash

# Upgrade Raspberry Pi Debian 11 Image to Debian 12
#
# Use Hundsbuah's process presented here:
# https://klipper.discourse.group/t/debian-12-and-klipper/10860/5
#
# NOTE: All instructions are ended in "-y" to eliminate user involvement 
#  in upgrade process


# Echo Colour Specifications
echoGreen(){
    echo -e "\e[32m${1}\e[0m"
}
echoRed(){
    echo -e "\e[31m${1}\e[0m"
}
echoBlue(){
    echo -e "\e[34m${1}\e[0m"
}
echoYellow(){
    echo -e "\e[33m${1}\e[0m"
}


# Process Start

echoGreen "Update all packages to the latest version"
echoRed "sudo apt update"
sudo apt update
echoRed "sudo apt upgrade -y"
sudo apt upgrade -y
echoRed "sudo apt dist-upgrade -y"
sudo apt dist-upgrade -y
echoRed "sudo apt --purge autoremove -y"
sudo apt --purge autoremove -y
echoRed "sudo apt autoclean -y"
sudo apt autoclean -y

echoGreen "Change apt to teh new Debian12 packages"
echoRed "sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list"
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
echoRed "sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/*"
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/*
echoRed "sudo sed -i 's/non-free/non-free non-free-firmware/g' /etc/apt/sources.list"
sudo sed -i 's/non-free/non-free non-free-firmware/g' /etc/apt/sources.list
echoRed "sudo sed -i 's/non-free/non-free non-free-firmware/g' /etc/apt/sources.list.d/*"
sudo sed -i 's/non-free/non-free non-free-firmware/g' /etc/apt/sources.list.d/*

echoGreen "Update packages"
echoRed "sudo apt update"
sudo apt update

echoGreen "Do a minimal system update"
echoRed "sudo apt upgrade --without-new-pkgs -y"
sudo apt upgrade --without-new-pkgs -y

echoGreen "Do the rest, full system update"
echoRed "sudo apt full-upgrade -y"
sudo apt full-upgrade -y

echoYellow "Finished - sudo reboot"