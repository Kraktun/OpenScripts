#!/bin/bash
set -eu

# needs the following variables set up

# RCLONE_SERVER_ADDRESS= # ip address of the server
# RCLONE_SERVER_USER= # user on the server to connect to with ssh
# RCLONE_SERVER_NAME= # name of the key to generate to connect to the server
# RCLONE_CLIENT_USER= # name of the local user that will be created to control rclone
# RCLONE_CLIENT_PASSWORD= # encrypted password for RCLONE_CLIENT_USER
# an encrypted password can be obtained with the command `openssl passwd -1 "my_password"`

echo
echo "#######################################"
echo -e "\t\tInstalling rclone-client"
echo "#######################################"
echo
echo "Press ENTER to continue"
read -p "" VAR
# create non root client user
echo "Adding new user $RCLONE_CLIENT_USER"
RCLONE_CLIENT_HOME=/home/$RCLONE_CLIENT_USER
sudo useradd -s /bin/bash -m -d $RCLONE_CLIENT_HOME $RCLONE_CLIENT_USER
echo $RCLONE_CLIENT_USER:$RCLONE_CLIENT_PASSWORD | sudo chpasswd -e

# define folder where to store the key
echo "Creating new key"
RCLONE_KEY_PATH=$RCLONE_CLIENT_HOME/certs/keys
sudo mkdir -p $RCLONE_KEY_PATH
sudo chown $RCLONE_CLIENT_USER:$RCLONE_CLIENT_USER $RCLONE_KEY_PATH
RCLONE_KEY_FILE=$RCLONE_KEY_PATH/$RCLONE_SERVER_NAME.key
# generate the key
# note that the $0 is necessary to pass the variable from the current user to the new one
sudo -H -u $RCLONE_CLIENT_USER bash -c 'cd $HOME && ssh-keygen -t rsa -b 4096 -f $0 -N ""' "$RCLONE_KEY_FILE"
# secure permissions
sudo chmod 0700 $RCLONE_KEY_PATH

# ask to add the key to server authorized keys
echo
echo "Now add the following public key to your rclone server authorized keys"
echo
sudo cat $RCLONE_KEY_FILE.pub
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
mkdir -p $RCLONE_CLIENT_HOME/.ssh
sudo chmod 700 $RCLONE_CLIENT_HOME/.ssh
touch $RCLONE_CLIENT_HOME/.ssh/known_hosts
sudo chmod 640 $RCLONE_CLIENT_HOME/.ssh/known_hosts
sudo chown -R $RCLONE_CLIENT_USER:$RCLONE_CLIENT_USER $RCLONE_CLIENT_HOME/.ssh
# add the server to the known hosts
# not secure, but I assume you know what you are doing
sudo -H -u $RCLONE_CLIENT_USER bash -c 'ssh-keyscan -H $0 >> $HOME/.ssh/known_hosts' "$RCLONE_SERVER_ADDRESS"
echo "Attempting a connection to the server"
sudo -H -u $RCLONE_CLIENT_USER bash -c 'echo dir | sftp -i $0 $1@$2' "$RCLONE_KEY_FILE" "$RCLONE_SERVER_USER" "$RCLONE_SERVER_ADDRESS"
echo 
echo "If you saw 'Connected to $RCLONE_SERVER_ADDRESS' you can configure rclone"
echo -e "with \trclone config"
echo
echo "---------------------------------------"
echo -e "\tInstallation complete"
echo "---------------------------------------"
echo
