#! /bin/bash

# Automate the process of creating the initial Katapult/Klipper firmware image and Flashing it onto the main controller board 
# This script requires:
# - Klipper has been installed
#   - The initial "make menuconfig" has been run
# - Katapult has been installed
#   - The initial "make menuconfig" has been run
# - "pip3 install pyserial" has been executed
# - The host is connected to the main controller using USB
# - The main controller board is in DFU mode
# + ".config" exists in ~/klipper and ~/Katapult

# This script performs the following actions:
# - 'sudo apt update' and 'sudo apt upgrade -y' to ensure the latest updates are loaded into the host
# - make the preconfigured Klipper firmware image
# - make the preconfigured Katapult firmware image
# - Burn Katapult formware image into the main controller
# - Burn Klipper formware image into the main controller
# - Create the 'can0' file in /etc/network/interfaces.d
# - Prompt the user for a reboot

# Written by: myke predko
# Last Update: 2023.09.21

# Questions and problems to be reported at https://klipper.discourse.group

# This software has only been tested on Raspberry Pi 4B and CM4 as well as the BTT CB1

# Users of this software run at their own risk as this software is "As Is" with no Warranty or Guarantee.  


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

# Exit Script if Folder is not found in root
exitIfFolderNotFound() {
  rootFile=`ls ~ -l`
  if [[ "$rootFile" == *"${1}"* ]]; then
    return 0 # True
  else
    echoRed "Error - ${1} not installed"
    exit 1
  fi
}

# Load Katapult if it's not installed
loadKatapult() {
  rootFile=`ls ~ -l`
  if [[ "$rootFile" == *"Katapult"* ]]; then
    echoYellow "Katapult Alreadly loaded"
  else
    echoYellow "Loading Katapult and pyserial"
    git clone https://github.com/Arksine/Katapult
	pip3 install pyserial
  fi
  return 0 # True
}

exitIfMainControllerUSBNotCorrect() {
  lsusbDevices=`lsusb`
  if [[ "$lsusbDevices" == *"${1}"* ]]; then
    return 0 # True
  else
    echoRed "Error - 'lsusb' does not return '${1}'"
    exit 1
  fi
}


# Mainline code follows
echoYellow "Flash Katapult and klipper into main controller board"

# Load in any pending updates regardless
# echoYellow "Performing 'sudo apt update'"
# sudo apt update
# echoYellow "Performing 'sudo apt upgrade -y'"
# sudo apt upgrade -y
echoYellow "Performing 'sudo apt-get install git -y'"
sudo apt-get install git -y 

# Check that the requirements are met for the application
echoYellow "Check for Klipper folder"
exitIfFolderNotFound "klipper"
loadKatapult
echoYellow "Check that the main controller is in DFU mode"
exitIfMainControllerUSBNotCorrect "0483:df11"

echoYellow "Build Klipper firmware image"
cd ~/klipper
make clean
make

# Build the firmware images
echoYellow "Build Katapult firmware image"
cd ~/Katapult
make clean
make

echoYellow "Flash Katapult firmage image into main controller"
sudo dfu-util -a 0 -D ~/Katapult/out/katapult.bin --dfuse-address 0x08000000:force:mass-erase:leave -d 0483:df11
sleep 1s
exitIfMainControllerUSBNotCorrect "OpenMoko"
sleep 1s

echoYellow "Flash Klipper firmware into main controller"
lsDevice=`ls /dev/serial/by-id/`
echoRed "$lsDevice"
python3 ~/Katapult/scripts/flash_can.py -d /dev/serial/by-id/$lsDevice

echoYellow "Create can0 file in /etc/network/interfaces.d"
can0Contents="allow-hotplug can0\niface can0 can static\n bitrate 500000\n up ifconfig $IFACE txqueuelen 256\n pre-up ip link set can0 type can bitrate 500000\n pre-up ip link set can0 txqueuelen 256"
can0Temp=$(mktemp)
echo -e $can0Contents > $can0Temp
sudo cp $can0Temp /etc/network/interfaces.d/can0

echoYellow "
#####################
###               ###
###  sudo reboot  ###
###               ###
#####################"