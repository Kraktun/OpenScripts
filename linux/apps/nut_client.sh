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
echo_purple "#######################################"
echo_purple "\t\tInstalling nut-client"
echo_purple "#######################################"
echo
echo_yellow "Press ENTER to continue"
read -p "" VAR

# check if control script exist
nut_control_not_exist() {
    echo_red "Nut control script not found. Aborting."
    exit 1
}
do_file_exist $SOURCE_CONFIG_FOLDER/nut/control_script.sh do_nothing_function nut_control_not_exist

echo_yellow "Installing package"
sudo apt-get -y -q install nut-client
echo_yellow "Configuring nut"
# set mode to client
sudo sed -i 's/MODE=none/MODE=netclient/' /etc/nut/nut.conf
# apply monitoring config
echo "RUN_AS_USER nut" | sudo tee -a /etc/nut/upsmon.conf
echo "MONITOR $NUT_UPS_NAME@$NUT_UPS_SERVER_IP 1 $NUT_UPS_SLAVE_USER $NUT_UPS_SLAVE_PASSWORD slave" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYCMD /usr/sbin/upssched" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYFLAG ONLINE SYSLOG+WALL+EXEC" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYFLAG LOWBATT SYSLOG+WALL+EXEC" | sudo tee -a /etc/nut/upsmon.conf
# reduce poll to 3 seconds (i.e. increase frequency)
sudo sed -i 's/POLLFREQALERT 5/POLLFREQALERT 3/' /etc/nut/upsmon.conf
# replace default control script
sudo sed -i 's_CMDSCRIPT /bin/upssched-cmd_#CMDSCRIPT /bin/upssched-cmd_' /etc/nut/upssched.conf
echo "CMDSCRIPT /opt/nut/upssched/control_script.sh" | sudo tee -a /etc/nut/upssched.conf
# add pipes
echo "PIPEFN /opt/nut/upssched/upssched.pipe" | sudo tee -a /etc/nut/upssched.conf
echo "LOCKFN /opt/nut/upssched/upssched.lock" | sudo tee -a /etc/nut/upssched.conf
# add shutdown timer
echo "# shutdown after $NUT_UPS_SHUTDOWN_SECONDS sec. on battery" | sudo tee -a /etc/nut/upssched.conf
echo "AT ONBATT * START-TIMER onbattshutdown $NUT_UPS_SHUTDOWN_SECONDS" | sudo tee -a /etc/nut/upssched.conf
echo "AT ONLINE * CANCEL-TIMER onbattshutdown" | sudo tee -a /etc/nut/upssched.conf
echo "AT ONBATT * EXECUTE onbattwarn" | sudo tee -a /etc/nut/upssched.conf
echo "AT LOWBATT * EXECUTE onbattshutdownnow" | sudo tee -a /etc/nut/upssched.conf
echo_yellow "Copying control script"
sudo mkdir -p /opt/nut/upssched
sudo cp $SOURCE_CONFIG_FOLDER/nut/control_script.sh /opt/nut/upssched/
sudo chmod g+x /opt/nut/upssched/control_script.sh
sudo chmod g+rwx /opt/nut/upssched
sudo chown -R root:nut /opt/nut/upssched

echo_yellow "Configuring startup service"
# wait for network to be up
sudo sed -i "s/After=local-fs.target network.target nut-server.service/After=local-fs.target network.target network-online.target nut-server.service\nWants=network-online.target/" /lib/systemd/system/nut-client.service
# add a sleep to wait for the server to get ready if necessary
sudo sed -i 's_\[Service\]_\[Service\]\nExecStartPre=/bin/sleep 25_' /lib/systemd/system/nut-client.service
# remove requirement for password for nut user for shutdown command
echo 'nut ALL=NOPASSWD:/usr/sbin/shutdown' | sudo EDITOR='tee -a' visudo

echo_yellow "Configuring email service"
sudo apt-get -y -q install msmtp msmtp-mta

nut_do_replace_config() {
    sudo cp $SOURCE_CONFIG_FOLDER/nut/msmtprc /etc/msmtprc
}
nut_ask_rewrite_email_service() {
    echo_yellow "A configuration file for the email service already exists in /etc/msmtprc."
    ask_yes_no_function "Do you want to replace it?" nut_do_replace_config do_nothing_function
}
do_file_exist /etc/msmtprc nut_ask_rewrite_email_service nut_do_replace_config

echo
echo_green "---------------------------------------"
echo_green "\tInstallation complete"
echo_green "---------------------------------------"
echo