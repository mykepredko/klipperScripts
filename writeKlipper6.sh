#! /bin/bash

# Change name to "KOI" for "Klipper Optimized Installation"
# - Get an ASCII fish logo?

# Command Line Options:
# KOIwrite -h | (configFilename [-s 250|500|1000])
# -h: Manual Page
# -s 250|500|1000 is the CAN bus data rate in kbps/if not specified the default is 500 kbps

# Automate the process of creating the initial Katapult/Klipper firmware image and Flashing it onto the main controller board 
# This script requires:
# - The host is connected to the main controller using USB
# - The main controller board is in DFU mode
# - The specified https://raw.githubusercontent.com/mykepredko/klipperScripts/main/*.menuconfig file exists 
# - The https://raw.githubusercontent.com/mykepredko/klipperScripts/main/can0 file exists
# + The https://raw.githubusercontent.com/mykepredko/klipperScripts/main/mcu.cfg prototype file exists
# + The reboot script exists

# This script performs the following actions:
# - Saves the user's home directory
# - Handles the command line options
#   + Displays the Manual Page Information when specified/Check and code in place but 
#   - Checks for the presence of the board menuconfig file
#   - Checks the optional data rate to make sure it's "250", "500" or "1000"
#   - Handles Erroneous command line options
# - 'sudo apt update' and 'sudo apt upgrade -y' to ensure the latest updates are loaded into the host
# - If Klipper is not installed then load in KIAUH and prompt user to install Klipper, Moonraker & Mainsail
# - Update Klipper to ensure that it's running at the latest level
# - Install Katapult and pyserial
# - Load in the preconfigured Klipper firmware image
#   - Add the specified Speed to the Klipper .config file
# - make the preconfigured Katapult firmware image
# - Burn Katapult formware image into the main controller using DFU
# - Burn Klipper formware image into the main controller using Katapult
#   - Save the results of "ls /dev/serial/by-id"
# - Create the 'can0' file in /etc/network/interfaces.d
#   - Located at: https://raw.githubusercontent.com/mykepredko/klipperScripts/main/can0
#   - Add  the specified Speed to the can0 file
# - Update the https://raw.githubusercontent.com/mykepredko/klipperScripts/main/mcu.cfg file in ~/printer_data/config with the following information:
#   [mcu]
#   # board=[typeFromCommandLineArgument] - use "^^^"
#   # usb_serial=[$resultsOf"ls /dev/serial/by-id"] - use "###"
#   # canbus_speed=[$canDataRate] - use "%%%" and will be updated with the reboot script
#   canbus_uuid: use "@@@" <= This will ahve to be determined at a later time
#   # home_directory=&&&
#   #restart_method: command
#   [temperature_sensor mcu_temp]
#   sensor_type: temperature_mcu
# - If can get CAN bus UUID then 
#   - Insert in mcu.cfg
# - else
#   - Create script code that updates the "mcu.cfg" file with the "canbus_uuid" which is to be run upon reboot
#   - Set the script to run on boot up (Ideally once but everytime as long as it doesn't rewrite the file is okay)
# + Automatically Reboot after 10s (giving the user a chance to Ctrl-C it)


# Files to check after execution:
# sudo nano ~/printer_data/config/mcu.cfg  <==  This is where the problem is
# sudo nano /etc/network/interfaces.d/can0
# sudo nano mcuUpdate2.sh
# sudo nano /etc/systemd/system/mcuUpdate2.service
# sudo nano klipper/.config
# sudo nano Katapult/.config


# Written by: myke predko
# Last Update: 2023.10.01

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
    sudo apt install python3-serial 
  fi
  return 0 # True
}

# Load KIAUH if it's not installed
loadKIAUH() {
  cd ~
  rootFile=`ls ~ -al`
  if [[ "$rootFile" == *"kiauh"* ]]; then
    echoYellow "KIAUH installed"
  else
    echoYellow "Loading KIAUH"
	git clone https://github.com/dw-0/kiauh.git
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
echoYellow "KOI - Klipper Optimized Installation"

cd ~
homeDirectory=`pwd`

# Check Input Parameters
# -h for help
# Look for main controller board menuconfig file
if [ "" == "$1" ]; then
  echoRed "No main controller board filename specified"
  exit 1
elif [ "-h" == "$1" ]; then
  echoRed "Put in Help Information for the application"
  exit 1
fi


menuConfigFileName="https://raw.githubusercontent.com/mykepredko/klipperScripts/main/$1.menuconfig"
if curl -f ${menuConfigFileName} >/dev/null 2>&1; then
  echoGreen "Specified main controller board filename found"
else
  echoRed "Specified main controller board filename not found"
  exit 1
fi
if [ "" = "$2" ]; then
  canDataRate="500"
elif [ "-s" != "$2" ]; then
  echoRed "Invalid Command Line Parameter"
  exit 1
elif [ "250" != "$3" ] && [ "500" != "$3" ] && [ "1000" != "$3" ]; then
  echoRed "Invalid CAN bus speed specified"
  exit 1
else
  canDataRate="$3"
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
sudo service klipper stop
cd ~/klipper
git pull
cd ~/moonraker
git pull
loadKatapult
loadKIAUH
exitIfMainControllerUSBNotCorrect "0483:df11"

# Load in any pending updates regardless
echoYellow "Performing 'sudo apt update'"
sudo apt update
echoYellow "Performing 'sudo apt upgrade -y'"
sudo apt upgrade -y


# Build the firmware images
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

echoYellow "Flash Klipper firmware into main controller"
lsDevice=`ls /dev/serial/by-id/`
echoRed "$lsDevice"
### "sudo" added to command below because of access failure(s)
sudo python3 $homeDirectory/Katapult/scripts/flashtool.py -d /dev/serial/by-id/$lsDevice -f $homeDirectory/klipper/out/klipper.bin


echoYellow "Create can0 file in /etc/network/interfaces.d"
can0Contents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/can0 -O -)
can0Contents=${can0Contents//$'%%%'/$canDataRate}
can0Contents=${can0Contents//$'\n'/\\n}
can0Temp=$(mktemp)
echo -e $can0Contents > $can0Temp
sudo cp $can0Temp /etc/network/interfaces.d/can0
sudo chmod +r /etc/network/interfaces.d/can0


echoYellow "Create mcu.cfg file in ~/printer_data/config"
mcuCfgContents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/mcu.cfg -O -)
mcuCfgContents=${mcuCfgContents//$'%%%'/$canDataRate}
mcuCfgContents=${mcuCfgContents//$'^^^'/$1}
mcuCfgContents=${mcuCfgContents//$'###'/$lsDevice}
mcuCfgContents=${mcuCfgContents//$'&&&'/$homeDirectory}
mcuCfgContents=${mcuCfgContents//$'\n'/\\\\n}  
mcuCfgTemp=$(mktemp)
echo -e $mcuCfgContents > $mcuCfgTemp
sudo cp $mcuCfgTemp $homeDirectory/printer_data/config/mcu.cfg
sudo chmod +r $homeDirectory/printer_data/config/mcu.cfg


sleep 5s  # Give system some time to restart and have CAN bus set up
can0UUIDs=`$homeDirectory/Katapult/scripts/flash_can.py -i can0 -q`
if [[ "$can0UUIDs" == *", Application: Klipper"* ]]; then  # Have the canbus UUID/Update mcu.cfg
  echoYellow "Can update mcu.cfg"

  klipperLeadUUID=${can0UUIDs%", Application: Klipper"*}
  klipperUUID=${klipperLeadUUID#*"UUID: "}

  mcuCfgRead=`cat $homeDirectory/printer_data/config/mcu.cfg`
  sudo rm $homeDirectory/printer_data/config/mcu.cfg
  mcuCfgRead=${mcuCfgRead//$'@@@'/$klipperUUID}
  mcuCfgRead=${mcuCfgRead//$'\n'/\\n}
  mcuCfgTemp=$(mktemp)
  echo -e $mcuCfgRead > $mcuCfgReadTemp
  sudo cp $mcuCfgReadTemp $homeDirectory/printer_data/config/mcu.cfg
  chmod +r $homeDirectory/printer_data/config/mcu.cfg

  sudo service klipper restart

  echoGreen "
#######################################################
###                                                 ###
###  System Ready for Toolhead Connection/Flashing  ###
###                                                 ###
#######################################################"
else # Don't have canbus UUID/Setup for later update of mcu.cfg
  echoYellow "Add mcuUpdate.sh in the home directory"
  
  mcuUpdateContents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/mcuUpdate2.sh -O -)
  mcuUpdateContents=${mcuUpdateContents//$'\n'/\\n}
  mcuUpdateTemp=$(mktemp)
  echo -e $mcuUpdateContents > $mcuUpdateTemp
  sudo cp $mcuUpdateTemp $homeDirectory/mcuUpdate2.sh
  sudo chmod +r $homeDirectory/mcuUpdate2.sh
  sudo chmod +x $homeDirectory/mcuUpdate2.sh

  echoYellow "Add mcuUpdate.service to systemd"
  mcuServiceContents=$(wget https://raw.githubusercontent.com/mykepredko/klipperScripts/main/mcuUpdate2.service -O -)
  mcuServiceContents=${mcuServiceContents//$'&&&'/$homeDirectory}
  mcuServiceContents=${mcuServiceContents//$'\n'/\\n}
  mcuServiceTemp=$(mktemp)
  echo -e $mcuServiceContents > $mcuServiceTemp
  sudo cp $mcuServiceTemp /etc/systemd/system/mcuUpdate2.service
  sudo chmod +r /etc/systemd/system/mcuUpdate2.service

  sudo systemctl daemon-reload
  sudo systemctl enable mcuUpdate2.service
  sudo systemctl start mcuUpdate2.service

# + Add 10s Countdown to the sudo reboot so user can halt it
  echoYellow "
###################################
###                             ###
###  sudo reboot in 10 seconds  ###
###                             ###
###################################"
  sleep 1s
  echoYellow "9 Seconds"
  sleep 1s
  echoYellow "8 Seconds"
  sleep 1s
  echoYellow "7 Seconds"
  sleep 1s
  echoYellow "6 Seconds"
  sleep 1s
  echoYellow "5 Seconds"
  sleep 1s
  echoYellow "4 Seconds"
  sleep 1s
  echoYellow "3 Seconds"
  sleep 1s
  echoYellow "2 Seconds"
  sleep 1s
  echoYellow "1 Second"
  echo "sudo reboot"  # Remove "echo" when ready to ship the code
fi
