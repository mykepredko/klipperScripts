#! /bin/bash

# Command Line Options:
# writeToolhead -h | canConfigFilename 
# -h: Manual Page

# Automate the process of creating the initial Katapult/Klipper firmware image and Flashing it onto the main controller board 
# This script requires:
# - The host is connected via Katapult to the main controller board using USB
# - The main controller board has Klipper loaded on it
# - The CAN controller board is in DFU mode and connected to the host
# - The specified https://raw.githubusercontent.com/mykepredko/klipperScripts/main/*.toolheadcfg file exists 
# - The /etc/network/interfaces.d/can0 file exists
# - The ~/printer_data/config/mcu.cfg file exists
# + The reboot script exists

# This script performs the following actions:
# - Saves the user's home directory
# - Handles the command line options
#   + Displays the Manual Page Information when specified/Check and code in place but 
#   + Exit if the *.toolheadcfg file does not exists
# + Exit If Klipper, Katapult, KIAUH are not installed 
# + Exit if there is no controller in DFU mode (use lsusb to check)
# + Exit if there is no mcu.cfg
# + Load in mcu.cfg
#   + Save CAN data rate ("canbus_speed")
# + Generate and save (in ~/printer_data/config) a "toolhead.cfg" file from the *.toolheadcfg file
#   + NOTE: the *.toolheadcfg file needs to have alias specifications for the 
# + Load in the preconfigured Klipper firmware build file (*.toolheadcfg) 
#   + Add the specified Speed to the Klipper .config file
# + make the preconfigured Katapult firmware image
# + make the preconfigured Klipper firmware image
# + Burn Katapult formware image into the main controller using DFU
# + Create toolhead.sh code that updates the "toolhead.cfg" file with the "canbus_uuid" which is to be run upon reboot
#   + Set the script to run on boot up (Ideally once but everytime as long as it doesn't rewrite the file is okay)
# + Prompt the user to power down, disconnect the USB cable and connect the CAN cable

# toolhead.sh Script:
# + Exit if the ~/printer_data/config/toolhead.cfg has the UUID loaded
# + Exit if there isn't a "Katapult Application" UUID after  polling the canbus 
# + Load the ~/printer_data/config/toolhead.cfg file and load in the UUID found previously
#   + Store the modified ~/printer_data/config/toolhead.cfg
# + Using the UUID, flash the toolhead with the Klipper image
# + Prompt the user to reboot


# Files to check after execution:
# sudo nano ~/printer_data/config/toolhead.cfg  
# sudo nano toolheadUpdate.sh
# sudo nano /etc/systemd/system/mcuUpdate2.service
# sudo nano klipper/.config
# sudo nano Katapult/.config


# Written by: myke predko
# Last Update: 2023.10.08

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
checkForFolder() {
  cd ~
  rootFile=`ls ~ -al`
  if [[ "$rootFile" == *"$1"* ]]; then
    echoYellow "$1 installed"
    return 0 # True
  else
    echoRed "$1  not installed"
    exit 1
  fi
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
echoYellow "COI - Klipper Optimized Installation/Toolhead.cfg Generator"

cd ~
homeDirectory=`pwd`

# Check Input Parameters
# -h for help
# Look for main controller board menuconfig file
if [ "" == "$1" ]; then
  echoRed "No toolhead controller specified"
  exit 1
elif [ "-h" == "$1" ]; then
  echoRed "Put in Help Information for the application"
  exit 1
else
  menuConfigFileName="https://raw.githubusercontent.com/mykepredko/klipperScripts/main/$1.toolheadcfg"
  if curl -f ${menuConfigFileName} >/dev/null 2>&1; then
    echoGreen "$1.toolheadcfg found"
  else
    echoRed "$1.toolheadcfg NOT found"
    exit 1
  fi
fi

checkForFolder "klipper"
checkForFolder "Katapult"
exitIfMainControllerUSBNotCorrect "0483:df11"

mcuCfgFile=$homeDirectory/printer_data/config/mcu.cfg
if [ -f "$mcuCfgFile" ]; then
  mcuCfgRead=`cat $homeDirectory/printer_data/config/mcu.cfg`
  canbusSpeed=$'canbus_speed='
  mcuCfgRead=${mcuCfgRead#*$canbusSpeed}
  if [ ${mcuCfgRead:0:1} = "1" ]; then
    canDataRate="1000"
  elif [ ${mcuCfgRead:0:1} = "5" ]; then
    canDataRate="500"
  else 
    canDataRate="250"
  fi
else
  echoRed "No mcu.cfg file - Run writeKlipper.sh"
  exit 1
fi


echoYellow "Create toolhead.cfg file for ~/printer_data/config"
toolheadCfgContents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/$1.toolheadcfg -O -)
toolheadCfgContents=${toolheadCfgContents//$'%%%'/$canDataRate}
toolheadCfgContents=${toolheadCfgContents//$'&&&'/$homeDirectory}
toolheadCfgContents=${toolheadCfgContents//$'\n'/\\\\n}  
toolheadCfgTemp=$(mktemp)
echo -e $toolheadCfgContents > $toolheadCfgTemp
sudo cp $toolheadCfgTemp $homeDirectory/printer_data/config/toolhead.cfg
sudo chmod +r $homeDirectory/printer_data/config/toolhead.cfg


echoYellow "Build Klipper & Katapult firmware images"
menuConfigFile=`wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/$1.menuconfig -O -`
klipperStart=$'klipper=\n'
katapultStart=$'\nKatapult=\n'
menuConfigFile=${menuConfigFile//$'%%%'/$canDataRate}
menuConfigKlipper=${menuConfigFile%$katapultStart*}
menuConfigKlipper=${menuConfigKlipper#*$klipperStart}
menuConfigKlipper=${menuConfigKlipper//$'\n'/\\n}

menuConfigKatapult=${menuConfigFile#*$katapultStart}
menuConfigKatapult=${menuConfigKatapult//$'\n'/\\n}


# Build the firmware images
cd $homeDirectory/Katapult
make clean
echo -e $menuConfigKatapult > .config
make

cd $homeDirectory/klipper
make clean
echo -e $menuConfigKlipper > .config
make


echoYellow "Flash Katapult firmage image into toolhead controller"
sudo dfu-util -a 0 -D ~/Katapult/out/katapult.bin --dfuse-address 0x08000000:force:mass-erase:leave -d 0483:df11


echoYellow "Add toolheadUpdate.sh in the home directory"
headerUpdateContents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/headerUpdate1.sh -O -)
headerUpdateContents=${headerUpdateContents//$'\n'/\\n}
headerUpdateTemp=$(mktemp)
echo -e $headerUpdateContents > $headerUpdateTemp
sudo cp $headerUpdateTemp $homeDirectory/headerUpdate1.sh
sudo chmod +r $homeDirectory/headerUpdate1.sh
sudo chmod +x $homeDirectory/headerUpdate1.sh

echoYellow "Add headerUpdate1.service to systemd"
headerServiceContents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/headerUpdate1.service -O -)
headerServiceContents=${headerServiceContents//$'&&&'/$homeDirectory}
headerServiceContents=${headerServiceContents//$'\n'/\\n}
headerServiceTemp=$(mktemp)
echo -e $headerServiceContents > $headerServiceTemp
sudo cp $headerServiceTemp /etc/systemd/system/headerUpdate1.service
sudo chmod +r /etc/systemd/system/headerUpdate1.service

sudo systemctl daemon-reload
sudo systemctl enable headerUpdate1.service
sudo systemctl start headerUpdate1.service

echoYellow "
######################################################
###                                                ###
###  Press Any Key to Power Down                   ###
###                                                ###
###  After Turning Off System Power:               ###
###  1.  Disconnect the USB Cable to the Toolhead  ###
###  2.  Connect the CAN Cable to the Toolhead     ###
###  3.  Turn System Power On                      ###
###                                                ###
######################################################"
read -N 1 -s
sudo shutdown -P +0
