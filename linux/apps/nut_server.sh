#!/bin/bash

set -eu

# requires libs functions

# needs the following variables set up
# and libs.sh loaded

# NUT_UPS_NAME= # Name of the ups
# NUT_UPS_SERVER_IP= # Ip of the server with nut
# NUT_UPS_MASTER_USER= # username of master user
# NUT_UPS_MASTER_PASSWORD= # password of master user
# NUT_UPS_SHUTDOWN_SECONDS= # Time in seconds to wait before shutdown after power loss
# SOURCE_CONFIG_FOLDER= # Folder with the config files


echo
echo_purple "#######################################"
echo_purple "\t\tInstalling nut-server"
echo_purple "#######################################"
echo
echo_yellow "Press ENTER to continue"
read -p "" VAR

m_nut_control_script=$SOURCE_CONFIG_FOLDER/nut/control_script.sh
m_nut_usb_conf=$SOURCE_CONFIG_FOLDER/nut/usb.conf
m_nut_users_conf=$SOURCE_CONFIG_FOLDER/nut/users.conf
m_nut_email_config=$SOURCE_CONFIG_FOLDER/nut/msmtprc

# check if control script exist
nut_file_not_exist() {
    local m_missing_file=$1
    echo_red "Nut $m_missing_file not found. Aborting."
    exit 1
}
do_file_exist $m_nut_control_script do_nothing_function nut_file_not_exist "control_script"
do_file_exist $m_nut_usb_conf do_nothing_function nut_file_not_exist "usb.conf"
do_file_exist $m_nut_users_conf do_nothing_function nut_file_not_exist "users.conf"
do_file_exist $m_nut_email_config do_nothing_function nut_file_not_exist "msmtprc"

echo_yellow "Installing package"
install_missing_packages install nut

echo_yellow "Configuring nut"
sudo chown nut /etc/nut/*
sudo /etc/init.d/nut-server restart
echo
# disabled, maybe it's not needed, and broken
#echo_purple "Disabling auto-shutdown"
#sudo sed -i 's=/sbin/upsmon -K >/dev/null 2>&1 && /sbin/upsdrvctl shutdown=#/sbin/upsmon -K >/dev/null 2>&1 && /sbin/upsdrvctl shutdown=' /lib/systemd/system-shutdown/nutshutdown

echo_purple "Adding usb config"
cat "$m_nut_usb_conf" | sudo tee -a /etc/nut/ups.conf

echo_purple "Starting service"
sudo upsdrvctl start

echo_purple "Configuring service"
sudo sed -i -E "s/MODE=.*/MODE=netserver/" /etc/nut/nut.conf
echo "LISTEN 127.0.0.1 3493" | sudo tee -a /etc/nut/upsd.conf
echo "LISTEN $NUT_UPS_SERVER_IP 3493" | sudo tee -a /etc/nut/upsd.conf

echo_yellow "Checking config"
ups_resp=$(upsc $NUT_UPS_NAME@localhost ups.status)
if [[ $ups_resp = "OL" ]]
then
    echo_green "Connection to ups service succeeded"
else
    echo_red "Connection to server failed. Aborting"
    exit 1
fi

echo_purple "Adding users config"
cat "$m_nut_users_conf" | sudo tee -a /etc/nut/upsd.users

echo_purple "Writing shutdown logic"
# apply monitoring config
echo "RUN_AS_USER nut" | sudo tee -a /etc/nut/upsmon.conf
echo "MONITOR $NUT_UPS_NAME@localhost 1 $NUT_UPS_MASTER_USER $NUT_UPS_MASTER_PASSWORD master" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYCMD /usr/sbin/upssched" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYFLAG ONLINE SYSLOG+WALL+EXEC" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYFLAG ONBATT SYSLOG+WALL+EXEC" | sudo tee -a /etc/nut/upsmon.conf
echo "NOTIFYFLAG LOWBATT SYSLOG+WALL+EXEC" | sudo tee -a /etc/nut/upsmon.conf
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
sudo cp $m_nut_control_script /opt/nut/upssched/
sudo chmod g+x /opt/nut/upssched/control_script.sh
sudo chmod g+rwx /opt/nut/upssched
sudo chown -R root:nut /opt/nut/upssched

echo_purple "Fixing up boot service"
sudo sed -i -E "s/(After=.*)/\1 network-online.target/" /lib/systemd/system/nut-server.service
sudo sed -i -E "s/(Wants=.*)/\1 network-online.target/" /lib/systemd/system/nut-server.service
sudo sed -i 's_\[Service\]_\[Service\]\nExecStartPre=/bin/sleep 15_' /lib/systemd/system/nut-server.service
sudo sed -i -E "s/(After=.*)/\1 network-online.target/" /lib/systemd/system/nut-client.service
sudo sed -i -E "s/(Wants=.*)/\1 network-online.target/" /lib/systemd/system/nut-client.service
sudo sed -i 's_\[Service\]_\[Service\]\nExecStartPre=/bin/sleep 25_' /lib/systemd/system/nut-client.service

echo_purple "Add crontab job to restart driver every day"
(sudo crontab -l ; echo "0 2 * * * systemctl restart nut-driver") | sudo crontab -

echo_yellow "Setting permissions"
# remove requirement for password for nut user for shutdown command
echo 'nut ALL=NOPASSWD:/usr/sbin/shutdown' | sudo EDITOR='tee -a' visudo

echo_purple "Enabling system service"
sudo systemctl enable nut-server
sudo systemctl start nut-server
sudo systemctl enable nut-client
sudo systemctl start nut-client

echo_yellow "Configuring email service"
sudo apt-get -y -q install msmtp msmtp-mta

nut_do_replace_config() {
    sudo cp $m_nut_email_config /etc/msmtprc
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