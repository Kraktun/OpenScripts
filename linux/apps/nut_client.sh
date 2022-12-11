#!/bin/bash

set -eu

# requires libs functions

# needs the following variables set up
# and libs.sh loaded

# NUT_UPS_NAME= # Name of the ups
# NUT_UPS_SERVER_IP= # Ip of the server with nut
# NUT_UPS_SLAVE_USER= # Username of the slave user
# NUT_UPS_SLAVE_PASSWORD= # Password for the slave user
# NUT_UPS_SHUTDOWN_SECONDS= # Time in seconds to wait before shutdown after power loss
# SOURCE_CONFIG_FOLDER= # Folder with the config files
# Must have a $SOURCE_CONFIG_FILE/nut/control_script.sh file and a $SOURCE_CONFIG_FOLDER/nut/msmtprc file.

echo
echo "#######################################"
echo -e "\t\tInstalling nut-client"
echo "#######################################"
echo
echo "Press ENTER to continue"
read -p "" VAR

# check if control script exist
nut_control_not_exist() {
    echo "Nut control script not found. Aborting."
    exit 1
}
do_file_exist $SOURCE_CONFIG_FOLDER/nut/control_script.sh do_nothing_function nut_control_not_exist

echo "Installing package"
sudo apt-get -y -q install nut-client
echo "Configuring nut"
# set mode to client
sudo sed -i 's/MODE=none/MODE=netclient/' /etc/nut/nut.conf
# apply monitoring config
sudo echo "RUN_AS_USER nut" >> /etc/nut/upsmon.conf
sudo echo "MONITOR $NUT_UPS_NAME@$NUT_UPS_SERVER_IP 1 $NUT_UPS_SLAVE_USER $NUT_UPS_SLAVE_PASSWORD slave" >> /etc/nut/upsmon.conf
sudo echo "NOTIFYCMD /usr/sbin/upssched" >> /etc/nut/upsmon.conf
sudo echo "NOTIFYFLAG ONLINE SYSLOG+WALL+EXEC" >> /etc/nut/upsmon.conf
sudo echo "NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC" >> /etc/nut/upsmon.conf
sudo echo "NOTIFYFLAG LOWBATT SYSLOG+WALL+EXEC" >> /etc/nut/upsmon.conf
# reduce poll to 3 seconds (i.e. increase frequency)
sudo sed -i 's/POLLFREQALERT 5/POLLFREQALERT 3/' /etc/nut/nut.conf
# replace default control script
sudo sed -i 's_CMDSCRIPT /bin/upssched-cmd_#CMDSCRIPT /bin/upssched-cmd_' /etc/nut/upssched.conf
sudo echo "CMDSCRIPT /opt/nut/upssched/control_script.sh" >> /etc/nut/upssched.conf
# add pipes
sudo echo "PIPEFN /opt/nut/upssched/upssched.pipe" >> /etc/nut/upssched.conf
sudo echo "LOCKFN /opt/nut/upssched/upssched.lock" >> /etc/nut/upssched.conf
# add shutdown timer
sudo echo "# shutdown after $NUT_UPS_SHUTDOWN_SECONDS sec. on battery" >> /etc/nut/upssched.conf
sudo echo "AT ONBATT * START-TIMER onbattshutdown $NUT_UPS_SHUTDOWN_SECONDS" >> /etc/nut/upssched.conf
sudo echo "AT ONLINE * CANCEL-TIMER onbattshutdown" >> /etc/nut/upssched.conf
sudo echo "AT ONBATT * EXECUTE onbattwarn" >> /etc/nut/upssched.conf
sudo echo "AT LOWBATT * EXECUTE onbattshutdownnow" >> /etc/nut/upssched.conf
echo "Copying control script"
sudo mkdir -p /opt/nut/upssched
sudo cp $SOURCE_CONFIG_FOLDER/nut/control_script.sh /opt/nut/upssched/
sudo chmod g+x /opt/nut/upssched/control_script.sh
sudo chmod g+rwx /opt/nut/upssched
sudo chown -R root:nut /opt/nut/upssched

echo "Configuring startup service"
# wait for network to be up
sudo sed -i "s/After=local-fs.target network.target nut-server.service/After=local-fs.target network.target network-online.target nut-server.service\nWants=network-online.target/" /lib/systemd/system/nut-client.service
# add a sleep to wait for the server to get ready if necessary
sudo sed -i 's_\[Service\]_\[Service\]\nExecStartPre=/bin/sleep 25_' /lib/systemd/system/nut-client.service
# remove requirement for password for nut user for shutdown command
echo 'nut ALL=NOPASSWD:/usr/sbin/shutdown' | sudo EDITOR='tee -a' visudo

echo "Configuring email service"
sudo apt-get -y -q install msmtp msmtp-mta

nut_do_replace_config() {
    sudo cp $SOURCE_CONFIG_FOLDER/nut/msmtprc /etc/msmtprc
}
nut_ask_rewrite_email_service() {
    echo "A configuration file for the email service already exists in /etc/msmtprc."
    ask_yes_no_function "Do you want to replace it?" nut_do_replace_config do_nothing_function
}
do_file_exist /etc/msmtprc nut_ask_rewrite_email_service nut_do_replace_config

echo
echo "---------------------------------------"
echo -e "\tInstallation complete"
echo "---------------------------------------"
echo