#! /bin/bash

# Change name to "KOImcuUpdate" for "Klipper Optimized Installation"
# - Get an ASCII fish logo?

# Command Line Options:
# None

# Automate the process of loading the CAN UUID into the ~/printer_data/config/toolhead.cfg if it is not there
# This script requires:
# Nothing.  If toolhead.cfg is missing or the canbus UUID is already loaded, it just ends. 

# This script performs the following actions:
# - Makes an array of userNames
# - Goes through each of the array elements:
#   - Checks to see if /home/userName[i] exists
#   - Checks to see if /home/userName[i]/printer_data/config/toolhead.cfg exists
#   - Checks to see if /home/userName[i]/printer_data/config/toolhead.cfg has "@@@" 
#   - Attempts to load the canbus system UUIDs
#   - Looks for the "Application Klipper" UUID
# - If all checks are satisified, the UUID replaces "@@@" in toolhead.cfg and the program exists

# To Run on Reboot
# - "sudo nano /etc/systemd/system/headerUpdate1.service" and put in the following data:
#[Unit]
#Description=Update the toolhead.cfg file with the CAN0 UUID
#After=network.target
#Requires=moonraker.service
#
#[Service]
#ExecStart=/home/&&&/toolheadUpdate1.sh
#Restart=always
#User=root
#Group=root
#Type=simple
#
#[Install]
#WantedBy=multi-user.target
#
#  Save as "/etc/systemd/system/headerUpdate1.service"
#
#  Run "sudo systemctl daemon-reload"
#  Run "sudo systemctl enable headerUpdate1.service"
#  Run "sudo systemctl start toolheadUpdate1.service"
#
#  Taken From: https://www.tutorialspoint.com/run-a-script-on-startup-in-linux


# Written by: myke predko
# Last Update: 2023.10/10

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

  toolheadFile=/home/$userName/printer_data/config/toolhead.cfg
  if [ -f "$toolheadFile" ]; then  # /home/$userName/printer_data/config/toolhead.cfg file exists

    toolheadCfgContents=`cat /home/$userName/printer_data/config/toolhead.cfg`
    if [[ "$toolheadCfgContents" == *"@@@"* ]]; then  # Have to set the canbus UUID

      can0UUIDs=`/home/$userName/Katapult/scripts/flash_can.py -i can0 -q`
#      echo "Time: $(date)" > /home/$userName/toolheadUpdateData3
#      echo "$can0UUIDs" >> /home/$userName/toolheadUpdateData3
      if [[ "$can0UUIDs" == *", Application: Katapult"* ]]; then  
        klipperLeadUUID=${can0UUIDs%", Application: Katapult"*}
        while [[ "$klipperLeadUUID" == *"UUID:"* ]]; do
          klipperLeadUUID=${klipperLeadUUID#*"UUID: "}
        done
      else 
        exit 1  # Can't get the canbus UUID
      fi

      sudo rm /home/$userName/printer_data/config/toolhead.cfg
      toolheadCfgContents=${toolheadCfgContents//$'@@@'/$klipperLeadUUID}
      toolheadCfgContents=${toolheadCfgContents//$'\n'/\\n}
#      echo "Time: $(date)" > /home/$userName/toolheadUpdateData4
#      echo "$toolheadCfgContents" >> /home/$userName/toolheadUpdateData4
      toolheadCfgTemp=$(mktemp)
      echo -e $toolheadCfgContents > $toolheadCfgTemp
      sudo cp $toolheadCfgTemp /home/$userName/printer_data/config/toolhead.cfg
      sudo chmod +r /home/$userName/printer_data/config/toolhead.cfg

      sudo python3 /home/$userName/Katapult/scripts/flashtool.py -u $klipperLeadUUID -f /home/$userName/klipper/out/klipper.bin

      systemctl stop headerUpdate1.service  ### - See if this ends this systemd service routine/Don't need it to execute any more
      
      exit 0 # All Done!
    fi

  fi
  
done
