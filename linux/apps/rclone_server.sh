#!/bin/bash
set -eu

# needs the following variables set up
# and libs.sh loaded

# RCLONE_HDD_GROUP= # group that owns the backup directory (e.g. in a external disk)
# RCLONE_SFTP_LIMITED_GROUP= # sftp group that is created with limited sftp access
# RCLONE_SERVER_HOME_DIRECTORY= # home directory of RCLONE_SERVER_USER, clients will be able to transfer files only to its subfolders
# RCLONE_SERVER_BACKUP_DIRECTORY= # must be a subfolder of RCLONE_SERVER_HOME_DIRECTORY, clients will be able to manage files only in this folder
# RCLONE_SERVER_USER= # name of the local user that will be created to control rclone
# RCLONE_SERVER_PASSWORD= # encrypted password for RCLONE_SERVER_USER
# an encrypted password can be obtained with the command `openssl passwd -1 "my_password"`

echo
echo_purple "#######################################"
echo_purple "\tInstalling rclone-server"
echo_purple "#######################################"
echo
echo "Rclone will be installed with the following configuration:"
echo -e "\tHDD GROUP:\t\t $RCLONE_HDD_GROUP"
echo -e "\tSFTP GROUP:\t\t $RCLONE_SFTP_LIMITED_GROUP"
echo -e "\tSFTP USER:\t\t $RCLONE_SERVER_USER"
echo -e "\tSFTP HOME DIR:\t\t $RCLONE_SERVER_HOME_DIRECTORY"
echo -e "\tSFTP BACKUP DIR:\t $RCLONE_SERVER_BACKUP_DIRECTORY"
echo
echo_yellow "Press ENTER to continue"
read -p "" VAR

echo_yellow "Installing packages"
curl https://rclone.org/install.sh | sudo bash
echo_yellow "Setting up groups and users"
sudo groupadd $RCLONE_SFTP_LIMITED_GROUP
sudo mkdir -p $RCLONE_SERVER_BACKUP_DIRECTORY
sudo ln -s $RCLONE_SERVER_HOME_DIRECTORY/ /home/$RCLONE_SERVER_USER
sudo useradd -s /bin/false -m -d /home/$RCLONE_SERVER_USER -G $RCLONE_HDD_GROUP,$RCLONE_SFTP_LIMITED_GROUP $RCLONE_SERVER_USER
echo $RCLONE_SERVER_USER:$RCLONE_SERVER_PASSWORD | sudo chpasswd -e
echo_yellow "Changing permissions for ssh folder"
sudo mkdir -p $RCLONE_SERVER_HOME_DIRECTORY/.ssh
sudo chown -R $RCLONE_SERVER_USER:$RCLONE_HDD_GROUP $RCLONE_SERVER_HOME_DIRECTORY/.ssh
sudo chmod 700 $RCLONE_SERVER_HOME_DIRECTORY/.ssh
echo_yellow "Setting up other directories"
sudo mkdir -p $RCLONE_SERVER_HOME_DIRECTORY/.local
sudo chown $RCLONE_SERVER_USER:$RCLONE_HDD_GROUP $RCLONE_SERVER_HOME_DIRECTORY/.local
sudo mkdir -p $RCLONE_SERVER_HOME_DIRECTORY/.cache
sudo chown $RCLONE_SERVER_USER:$RCLONE_HDD_GROUP $RCLONE_SERVER_HOME_DIRECTORY/.cache
create_keys () {
    echo_yellow "Creating keys"
    sudo -H -u $RCLONE_SERVER_USER bash -c 'cd $HOME && touch .ssh/authorized_keys && ssh-keygen -t rsa -b 4096 -f .ssh/id_rsa -N ""'
}
do_file_exist "$RCLONE_SERVER_HOME_DIRECTORY/.ssh/id_rsa" do_nothing_function create_keys
echo_yellow "Setting up backup dir permissions"
sudo chown root $RCLONE_SERVER_HOME_DIRECTORY
sudo chmod 755 $RCLONE_SERVER_HOME_DIRECTORY
sudo chown $RCLONE_SERVER_USER:$RCLONE_HDD_GROUP $RCLONE_SERVER_BACKUP_DIRECTORY
sudo chmod g+rwx $RCLONE_SERVER_BACKUP_DIRECTORY
echo_yellow "Restricting sftp mode"
sudo sed -i 's_Subsystem\tsftp\t/usr/lib/openssh/sftp-server_#Subsystem\tsftp\t/usr/lib/openssh/sftp-server\nSubsystem\tsftp\tinternal-sftp_' /etc/ssh/sshd_config
sudo echo -e "Match Group $RCLONE_SFTP_LIMITED_GROUP\n  ChrootDirectory %h \n  ForceCommand internal-sftp \n  AllowTCPForwarding no \n  X11Forwarding no" >> /etc/ssh/sshd_config
sudo service ssh restart
echo
echo_green "---------------------------------------"
echo_green "\tInstallation complete"
echo_green "---------------------------------------"
echo
echo_yellow "Now setup the client and add it to the authorized keys"
echo
