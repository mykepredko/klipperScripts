#! /bin/bash

# Change name to "KOImcuUpdate" for "Klipper Optimized Installation"
# - Get an ASCII fish logo?

# Command Line Options:
# None

# Automate the process of loading the CAN UUID into the ~/printer_data/config/mcu.cfg if it is not there
# This script requires:
# Nothing.  If mcu.cfg is missing or the canbus UUID is already loaded, it just ends. 

# This script performs the following actions:
# - Makes an array of userNames
# - Goes through each of the array elements:
#   - Checks to see if /home/userName[i] exists
#   - Checks to see if /home/userName[i]/printer_data/config/mcu.cfg exists
#   - Checks to see if /home/userName[i]/printer_data/config/mcu.cfg has "@@@" 
#   - Attempts to load the canbus system UUIDs
#   - Looks for the "Application Klipper" UUID
# - If all checks are satisified, the UUID replaces "@@@" in mnu.cfg and the program exists

# To Run on Reboot
# - "sudo nano /etc/systemd/system/mcuUpdate2.service" and put in the following data:
#[Unit]
#Description=Update the mcu.cfg file with the CAN0 UUID
#After=network.target
#Requires=moonraker.service
#
#[Service]
#ExecStart=/home/biqu/mcuUpdate2.sh
#Restart=always
#User=root
#Group=root
#Type=simple
#
#[Install]
#WantedBy=multi-user.target
#  Run "sudo systemctl daemon-reload"
#  Run "sudo systemctl enable mcuUpdate2.service"
#  Run "sudo systemctl start mcuUpdate2.service"
#
#  Taken From: https://www.tutorialspoint.com/run-a-script-on-startup-in-linux


# Written by: myke predko
# Last Update: 2023.09.30

# Questions and problems to be reported at https://klipper.discourse.group

# This software has only been tested on Raspberry Pi 4B and CM4 as well as the BTT CB1

# Users of this software run at their own risk as this software is "As Is" with no Warranty or Guarantee.  


# Mainline code follows
#echo "Last reboot time: $(date)" > /etc/motd  # Create file in /etc/ to show the script is running

homeDirectories=`ls /home -l`
readarray -t userNameArray <<< "$homeDirectories"
userNameSize=${#userNameArray[@]}
for (( i=1; i<userNameSize; ++i )); 
do
  userName=${userNameArray[$i]##* }

  mcuFile=/home/$userName/printer_data/config/mcu.cfg
  if [ -f "$mcuFile" ]; then  # /home/$userName/printer_data/config/mcu.cfg file exists

    mcuCfgContents=`cat /home/$userName/printer_data/config/mcu.cfg`
    if [[ "$mcuCfgContents" == *"@@@"* ]]; then  # Have to set the canbus UUID

      can0UUIDs=`/home/$userName/Katapult/scripts/flash_can.py -i can0 -q`
#      echo "Time: $(date)" > /home/$userName/mcuUpdateData3
#      echo "$can0UUIDs" >> /home/$userName/mcuUpdateData3
      if [[ "$can0UUIDs" == *", Application: Klipper"* ]]; then  # Have the canbus UUI
        klipperLeadUUID=${can0UUIDs%", Application: Klipper"*}
        klipperUUID=${klipperLeadUUID#*"UUID: "}
      else 
        exit 1  # Can't get the canbus UUID
      fi

      sudo rm /home/$userName/printer_data/config/mcu.cfg
      mcuCfgContents=${mcuCfgContents//$'@@@'/$klipperUUID}
      mcuCfgContents=${mcuCfgContents//$'\n'/\\n}
#      echo "Time: $(date)" > /home/$userName/mcuUpdateData4
#      echo "$mcuCfgContents" >> /home/$userName/mcuUpdateData4
      mcuCfgTemp=$(mktemp)
      echo -e $mcuCfgContents > $mcuCfgTemp
      sudo cp $mcuCfgTemp /home/$userName/printer_data/config/mcu.cfg
      sudo chmod +r /home/$userName/printer_data/config/mcu.cfg
      exit 0 # All Done!
    fi

  fi
  
done
