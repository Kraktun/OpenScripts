#!/bin/bash
set -eu

# needs the following variables set up

# RCLONE_SERVER_ADDRESS= # ip address of the server
# RCLONE_SERVER_USER= # user on the server to connect to with ssh
# RCLONE_SERVER_NAME= # name of the remote and the key to generate to connect to the server
# RCLONE_CLIENT_USER= # name of the local user that will be created to control rclone
# RCLONE_CLIENT_PASSWORD= # encrypted password for RCLONE_CLIENT_USER
# an encrypted password can be obtained with the command `openssl passwd -1 "my_password"`

echo
echo_yellow "#######################################"
echo_yellow "\t\tInstalling rclone-client"
echo_yellow "#######################################"
echo
echo "Press ENTER to continue"
read -p "" VAR
# create non root client user
echo "Adding new user $RCLONE_CLIENT_USER"
rclone_client_home=/home/$RCLONE_CLIENT_USER
sudo useradd -s /bin/bash -m -d $rclone_client_home $RCLONE_CLIENT_USER
echo $RCLONE_CLIENT_USER:$RCLONE_CLIENT_PASSWORD | sudo chpasswd -e

# define folder where to store the key
echo "Creating new key"
rclone_key_path=$rclone_client_home/certs/keys
sudo mkdir -p $rclone_key_path
sudo chown $RCLONE_CLIENT_USER:$RCLONE_CLIENT_USER $rclone_key_path
rclone_key_file=$rclone_key_path/$RCLONE_SERVER_NAME.key
# generate the key
# note that the $0 is necessary to pass the variable from the current user to the new one
sudo -H -u $RCLONE_CLIENT_USER bash -c 'cd $HOME && ssh-keygen -t rsa -b 4096 -f $0 -N ""' "$rclone_key_file"
# secure permissions
sudo chmod 0700 $rclone_key_path

# ask to add the key to server authorized keys
echo
echo "Now add the following public key to your rclone server authorized keys"
echo
sudo cat $rclone_key_file.pub
echo
echo "Press ENTER to continue"
read -p "" VAR
echo "-----------------------------------------------------"
echo

echo "Installing rclone"
curl https://rclone.org/install.sh | sudo bash
echo

# attempt connection
echo "Adding server to known hosts"
mkdir -p $rclone_client_home/.ssh
sudo chmod 700 $rclone_client_home/.ssh
touch $rclone_client_home/.ssh/known_hosts
sudo chmod 640 $rclone_client_home/.ssh/known_hosts
sudo chown -R $RCLONE_CLIENT_USER:$RCLONE_CLIENT_USER $rclone_client_home/.ssh
# add the server to the known hosts
# not secure, but I assume you know what you are doing
sudo -H -u $RCLONE_CLIENT_USER bash -c 'ssh-keyscan -H $0 >> $HOME/.ssh/known_hosts' "$RCLONE_SERVER_ADDRESS"
echo "Attempting a connection to the server."
echo "If it asks for a password, connection failed."
rclone_connection_result=`sudo -H -u $RCLONE_CLIENT_USER bash -c 'echo dir | sftp -i $0 $1@$2 | head -n 1' "$rclone_key_file" "$RCLONE_SERVER_USER" "$RCLONE_SERVER_ADDRESS"`
echo 
if [ "$rclone_connection_result" = "sftp> dir" ]; then
    echo "Connection to server was successful"
else
    echo "Connection to server failed"
    exit 1
fi

rclone_config_file=`sudo -H -u $RCLONE_CLIENT_USER bash -c 'rclone config file  | sed -n "2 p"'`
echo
echo "Press ENTER to write remote to config file: $rclone_config_file"
read -p "" VAR
echo "[$RCLONE_SERVER_NAME]" >> $rclone_config_file
echo "type = sftp" >> $rclone_config_file
echo "host = $RCLONE_SERVER_ADDRESS" >> $rclone_config_file
echo "user = $RCLONE_SERVER_USER" >> $rclone_config_file
echo "key_file = $rclone_key_file" >> $rclone_config_file
echo "md5sum_command = none" >> $rclone_config_file
echo "sha1sum_command = none" >> $rclone_config_file
echo "" >> $rclone_config_file

echo
echo_green "---------------------------------------"
echo_green "\tInstallation complete"
echo_green "---------------------------------------"
echo
