#! /bin/bash

# Change name to "KOI" for "Klipper Optimized Installation"
# - Get an ASCII fish logo?

# Command Line Options:
# KOIwrite -h | (configFilename [-s 250|500|1000])
# -h: Manual Page
# -s 250|500|1000 is the CAN bus data rate in kbps/if not specified the default is 500 kbps

# Automate the process of creating the initial Katapult/Klipper firmware image and Flashing it onto the main controller board 
# This script requires:
# - Klipper has been installed
#   - The initial "make menuconfig" has been run
# - Katapult has been installed
#   - The initial "make menuconfig" has been run
# - "pip3 install pyserial" has been executed
# - The host is connected to the main controller using USB
# - The main controller board is in DFU mode
# - Use the specified https://raw.githubusercontent.com/mykepredko/klipperScripts/main/*.menuconfig file exists 
# + The can0 file from github
# + Add the specified CAN data rate 

# This script performs the following actions:
# + Displays the Manual Page Information when specified or if the command line options are erroneous
# - 'sudo apt update' and 'sudo apt upgrade -y' to ensure the latest updates are loaded into the host
# - make the preconfigured Klipper firmware image
#   + Add the specified Speed to the Klipper .config file
# - make the preconfigured Katapult firmware image
# - Burn Katapult formware image into the main controller
# - Burn Klipper formware image into the main controller
# - Create the 'can0' file in /etc/network/interfaces.d
#   - Located at: https://raw.githubusercontent.com/mykepredko/klipperScripts/main/can0
#   + Add  the specified Speed to the can0 file
# - Prompt the user for a reboot
# + Disable the comments for 'sudo apt update' and 'sudo apt upgrade -y'

# Written by: myke predko
# Last Update: 2023.09.22

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
loadKlipper() {
  cd ~
  rootFile=`ls ~ -al`
  if [[ "$rootFile" == *"klipper"* ]]; then
    echoYellow "Klipper installed"
    return 0 # True
  else
    echoRed "Klipper  not installed"
	echoYellow "Installing KIAUH"
	cd ~
    git clone https://github.com/dw-0/kiauh.git
	echoYellow "Execute ./kiauh/kiauh.sh"
	echoYellow "Add Klipper, Moonraker and Mainsail/Fluidd to the host"
    exit 1
  fi
}

# Load Katapult if it's not installed
loadKatapult() {
  cd ~
  rootFile=`ls ~ -al`
  if [[ "$rootFile" == *"Katapult"* ]]; then
    echoYellow "Katapult installed"
  else
    echoYellow "Loading Katapult and pyserial"
    git clone https://github.com/Arksine/Katapult
#	pip3 install pyserial
    sudo apt install python3-serial # - Suggested by Sineos, try for all platforms
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
canDataRate="500"
echoYellow "Flash Katapult and klipper into main controller board"

# Save the current executing folder to return after execution
cwd=$(pwd)

# Check Input Parameters
# -h for help
# Filename (actually done below)
# 250/500/1000 for CAN bus Speed

# Look for main controller board menuconfig file
if [ "$1" == "" ]; then
  echoRed "No main controller board filename specified"
  exit 1
fi
menuConfigFileName="https://raw.githubusercontent.com/mykepredko/klipperScripts/main/$1.menuconfig"
if curl -f ${menuConfigFileName} >/dev/null 2>&1; then
  echoGreen "Specified main controller board filename found"
else
  echoRed "Specified main controller board filename not found"
  exit 1
fi
menuConfigFile=`wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/$1.menuconfig -O -`
klipperStart=$'klipper=\n'
katapultStart=$'\nKatapult=\n'
menuConfigFile=${menuConfigFile//$'%%%'/$canDataRate}
menuConfigKlipper=${menuConfigFile%$katapultStart*}
menuConfigKlipper=${menuConfigKlipper#*$klipperStart}
menuConfigKlipper=${menuConfigKlipper//$'\n'/\\n}

menuConfigKatapult=${menuConfigFile#*$katapultStart}
menuConfigKatapult=${menuConfigKatapult//$'\n'/\\n}


echoYellow "Check for Klipper, Katapult and main controller is in DFU mode"
sudo apt-get install git -y 
loadKlipper 
loadKatapult
exitIfMainControllerUSBNotCorrect "0483:df11"

# Load in any pending updates regardless
# echoYellow "Performing 'sudo apt update'"
# sudo apt update
# echoYellow "Performing 'sudo apt upgrade -y'"
# sudo apt upgrade -y


echoYellow "Update klipper"
cd ~/klipper
git pull
sudo service klipper restart

echoYellow "Build Katapult firmware image"
cd ~/Katapult
make clean
echo -e $menuConfigKatapult > .config
make

echoYellow "Build Klipper firmware image"
# Use the downloaded config
# Set the CAN data rate
cd ~/klipper
make clean
echo -e $menuConfigKlipper > .config
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
# Check to see if the file already exists?  
can0Contents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/can0 -O -)
can0Contents=${can0Contents//$'%%%'/$canDataRate}
can0Contents=${can0Contents//$'\n'/\\n}
can0Temp=$(mktemp)
echo -e $can0Contents > $can0Temp
sudo cp $can0Temp /etc/network/interfaces.d/can0


echoYellow "
#####################
###               ###
###  sudo reboot  ###
###               ###
#####################"
