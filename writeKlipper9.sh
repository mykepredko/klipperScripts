#! /bin/bash

# Change name to "KOImain" for "Klipper Optimized Installation"
# - Get an ASCII fish logo?

# Command Line Options:
# KOImain -h | (configFilename [-s 250|500|1000])
# -h: Manual Page
# -s 250|500|1000 is the CAN bus data rate in kbps/if not specified the default is 500 kbps

# Automate the process of creating the initial Katapult/Klipper firmware image and Flashing it onto the main controller board 
# This script requires:
# - The host is connected to the main controller using USB
# - The main controller board is in DFU mode
# - The specified https://raw.githubusercontent.com/mykepredko/klipperScripts/main/*.menuconfig file exists 
# - The https://raw.githubusercontent.com/mykepredko/klipperScripts/main/can0 file exists
# - The https://raw.githubusercontent.com/mykepredko/klipperScripts/main/mcu.cfg prototype file exists
# N/A - The reboot script exists
#   - This is no longer a requirement as the initial process for setting up the main controller no longer requires a reboot

# This script performs the following actions:
# - Saves the user's home directory
# - Handles the command line options
#   + Displays the Manual Page Information when specified/Check and code in place but 
#   - Checks for the presence of the board menuconfig file
#   - Checks the optional data rate to make sure it's "250", "500" or "1000"
#   - Handles Erroneous command line options
# - 'sudo apt update' and 'sudo apt upgrade -y' to ensure the latest updates are loaded into the host
# - If KIAUH is not installed, then load it in
# + If Klipper (and Moonraker & Mainsail) are NOT installed
#   + Install them using the KIAUH methods
# + Else 
#   + Perform update to Klipper, Moonraker & Mainsail using KIAUH methods

# - If Katapult not installed 
#   - Install Katapult and pyserial
# - Load in the preconfigured Klipper firmware image for the specified main controller board
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
# + Install KlipperScreen information for CM4 from: https://github.com/raspberrypi/documentation/blob/develop/documentation/asciidoc/computers/compute-module/cmio-display.adoc#quickstart-guide-display-only
#   + Have to determine if running a CM4
# + Install acelerometer code from: https://www.klipper3d.org/Measuring_Resonances.html#software-installation
# - Delay 5s for CAN bus UUID to become available
# - Insert in mcu.cfg
# - Prompt user to set up for "KOItoolhead" by:
#   - Connecting the toolhead PCB to the host using a USB cable
#   - Place the toolhead PCB in DFU mode
#   - Execute "KOItoolhead"


# Files to check after execution:
#  ~/printer_data/config/mcu.cfg
#  /etc/network/interfaces.d/can0
#  ~/klipper/.config
#  ~/Katapult/.config


# Written by: myke predko
# Last Update: 2023.10.11
#              2024.01.02 - Added KlipperScreen for CM4 Install
#                         - Added acelerometer code install

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

# Check to see if Klipper is there and load/update it
loadOrUpdateKlipper() {
local instance_names  ##### - This is how the variable is declared in "start_klipper_setup"
local klipper_systemd_services


cd ~
rootFile=`ls ~ -al`

KIAUH_SRCDIR="$homeDirectory/kiauh"
for script in "${KIAUH_SRCDIR}/scripts/"*.sh; do . "${script}"; done
for script in "${KIAUH_SRCDIR}/scripts/ui/"*.sh; do . "${script}"; done
##### Above is from the start of kiauh.sh
check_euid
init_logfile
set_globals  
##### Above is at the End of kiauh.sh mainline
init_ini    ### save all installed webinterface ports to the ini file
##### Above is done in main_menu
if [[ "$rootFile" == *"klipper"* ]]; then
  echoYellow "Klipper installed"
  echoYellow "Updating Klipper"
  update_klipper
#  echoYellow "Updating Moonraker"
#  update_moonraker
#  echoYellow "Updating Mainsail"
#  update_mainsail
#  update_all
##### From update_menu
  echoGreen "Update of Klipper applications Complete!"
else
  echoRed "Klipper not installed"
  echoYellow "Executing 'run_klipper_setup \"3\" \"printer\"' in KIAUH Code"
  fetch_webui_ports
  set_multi_instance_names
##### Above is done in install_menu
  klipper_systemd_services=$(klipper_systemd)
  if [[ -n ${klipper_systemd_services} ]]; then
    echoRed "Klipper Instance already installed"
    exit 1
  fi
#### Above is done in "start_klipper_setup"    
  instance_names+=("printer")
  run_klipper_setup "3" "${instance_names[@]}"
    
  echoYellow "Executing 'moonraker_setup_dialog' in KIAUH Code"
  moonraker_setup_dialog
    
  echoYellow "Executing 'install_mainsail' in KIAUH Code"
  install_mainsail

  echoGreen "Klipper, Moonrake & Mainsail Installed!"
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
set -e
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


# Load in any pending updates regardless
echoYellow "Performing 'sudo apt update'"
sudo apt update
echoYellow "Performing 'sudo apt upgrade -y'"
sudo apt upgrade -y
#sudo apt-get upgrade -y


echoYellow "Check for Klipper, Katapult and main controller is in DFU mode"
exitIfMainControllerUSBNotCorrect "0483:df11"
sudo apt-get install git -y 
loadKIAUH
loadOrUpdateKlipper


echoYellow "Load Katapult"
sudo service klipper stop
loadKatapult


# Build the firmware images
echoYellow "Build Katapult firmware image"
cd $homeDirectory/Katapult
make clean
echo -e $menuConfigKatapult > .config
make

echoYellow "Build Klipper firmware image"
# Use the downloaded config
# Set the CAN data rate
cd $homeDirectory/klipper
make clean
echo -e $menuConfigKlipper > .config
make


set +e  ### Ignore returned errors (primarily from the "dfu-util" statement following


echoYellow "Flash Katapult firmage image into main controller"
sudo dfu-util -a 0 -D ~/Katapult/out/katapult.bin --dfuse-address 0x08000000:force:mass-erase:leave -d 0483:df11
sleep 1s

echoYellow "Flash Klipper firmware into main controller"
lsDevice=`ls /dev/serial/by-id/`
echoRed "$lsDevice"
if [[ "$lsDevice" == *"No such file or directory"* ]]; then
  echoRed "\"No such file or directory\" Encountered after DFU programming."
  exit 1
fi
sudo python3 $homeDirectory/Katapult/scripts/flashtool.py -d /dev/serial/by-id/$lsDevice -f $homeDirectory/klipper/out/klipper.bin


set -e  ### Enable Stop on any errors encountered


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


echoYellow "Install Code for CM4 KlipperScreen"
sudo wget https://datasheets.raspberrypi.com/cmio/dt-blob-disp1-only.bin -O /boot/firmware/dt-blob.bin


echoYellow "Install Code for Measuring Resonances"
sudo apt update
sudo apt install python3-numpy python3-matplotlib libatlas-base-dev
~/klippy-env/bin/pip install -v numpy


echoYellow "Update mcu.cfg"
sleep 5s  # Give system some time to restart and have CAN bus set up
can0UUIDs=`$homeDirectory/Katapult/scripts/flash_can.py -i can0 -q`
klipperLeadUUID=${can0UUIDs%", Application: Klipper"*}
klipperUUID=${klipperLeadUUID#*"UUID: "}

mcuCfgRead=`cat $homeDirectory/printer_data/config/mcu.cfg`
sudo rm $homeDirectory/printer_data/config/mcu.cfg
mcuCfgRead=${mcuCfgRead//$'@@@'/$klipperUUID}
mcuCfgRead=${mcuCfgRead//$'\n'/\\n}
mcuCfgReadTemp=$(mktemp)
echo -e $mcuCfgRead > $mcuCfgReadTemp
sudo cp -f $mcuCfgReadTemp $homeDirectory/printer_data/config/mcu.cfg
sudo chmod +r $homeDirectory/printer_data/config/mcu.cfg

#  sudo service klipper restart

echoGreen "
############################################################
###                                                      ###
###  System Ready for Toolhead Connection/Flashing       ###
###                                                      ###
###  1. Connect the Toolhead to the host using USB       ###
###  2. Boot the Toolhead controller in DFU mode         ###
###  3. Finally, run 'KOItoolhead'                       ###
###                                                      ###
############################################################"
