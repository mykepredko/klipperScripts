#! /bin/bash

# Automate the process of updating the main controller board klipper firmware image
# This script requires that "klipper.bin" has already been built and is in the ~/klipper folder
# writeUpdate1 - Basic Operation
# writeUpdate2 - Add checks for responses to flash_can.py and ls /dev/serial/by-id/

# Written by: myke predko
# Last Update: 2023.09.21

# Questions and problems to be reported at https://klipper.discourse.group

# This software has only been tested on Raspberry Pi 4B and CM4

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


echoYellow "Flash ~/klipper/out/klipper.bin into Controller"

sudo service klipper stop

echoYellow "~/Katapult/scripts/flash_can.py -i can0 -q"
can0UUIDs=`~/Katapult/scripts/flash_can.py -i can0 -q`
if [[ "$can0UUIDs" == *", Application: Klipper"* ]]; then
  klipperLeadUUID=${can0UUIDs%", Application: Klipper"*}
  klipperUUID=${klipperLeadUUID#*"UUID: "}
else
  echoRed "Error - 'flash_can.py -i can0 -q' does not return ', Application: Klipper'"
  sudo service klipper restart
  exit 1
fi

echoYellow "python3 ~/Katapult/scripts/flash_can.py -r -u $klipperUUID"
python3 ~/Katapult/scripts/flash_can.py -r -u $klipperUUID

sleep 1s

echoYellow "ls /dev/serial/by-id/"
klipperSerialID=`ls /dev/serial/by-id/`
if [[ "$klipperSerialID" == *"No such file or directory"* ]]; then
  echoRed "Error - 'ls /dev/serial/by-id/' returns 'No such file or directory'"
  sudo service klipper restart
  exit 1
fi

echoYellow "python3 ~/Katapult/scripts/flash_can.py -d /dev/serial/by-id/$klipperSerialID"
python3 ~/Katapult/scripts/flash_can.py -d /dev/serial/by-id/$klipperSerialID

sleep 1s

echoYellow "~/Katapult/scripts/flash_can.py -i can0 -q"
~/Katapult/scripts/flash_can.py -i can0 -q

sudo service klipper restart
