#!/bin/bash
set -eu

# needs the following variables set up
# and libs.sh loaded

# RESTIC_USER= # name of the user that will control restic
# RESTIC_PASSWORD= #password of the user above
# RESTIC_BACKUP_DIRECTORY= # directory that restic will have access to
# RESTIC_HDD_GROUP= # group that owns the $RESTIC_BACKUP_DIRECTORY
# SOURCE_CONFIG_FOLDER= # folder that contains the configuration files and scripts
#   $SOURCE_CONFIG_FOLDER/restic/conf and $SOURCE_CONFIG_FOLDER/restic/scripts are assumed to exist and contain the aforementioned files

# currently supports only arm32 and 64, populate the required RESTIC_ARCH for other architectures

echo
echo_purple "#######################################"
echo_purple "\tInstalling restic"
echo_purple "#######################################"
echo
echo_yellow "Press ENTER to continue"
read -p "" VAR

RESTIC_VERSION=`curl -sL https://api.github.com/repos/restic/restic/releases/latest | jq -r ".tag_name"`
RESTIC_VERSION="${RESTIC_VERSION:1}"
MY_ARCH=`uname -m`
if [ "$MY_ARCH" = "aarch64" ]; then # arm64
  RESTIC_ARCH="arm64"
elif [ "$MY_ARCH" = "armv7l" ]; then # arm32
  RESTIC_ARCH="arm"
else
  echo "Unknown architecture"
  exit 1
fi
echo
echo "Restic version $RESTIC_VERSION and arch $RESTIC_ARCH will be installed with user $RESTIC_USER"
echo "Backup folder is $RESTIC_BACKUP_DIRECTORY"
echo
echo_yellow "Press ENTER to continue"
read -p "" VAR

create_new_user $RESTIC_USER $RESTIC_PASSWORD
sudo mkdir /home/$RESTIC_USER/bin
sudo chown $RESTIC_USER:$RESTIC_USER /home/$RESTIC_USER/bin
sudo -H -u $RESTIC_USER bash -c "curl -L https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_${RESTIC_ARCH}.bz2 | bunzip2 > /home/$RESTIC_USER/bin/restic"
sudo chmod 750 /home/$RESTIC_USER/bin/restic
echo_yellow "Copying credentials"
sudo mkdir -p /home/$RESTIC_USER/restic/conf
sudo chown $RESTIC_USER:root /home/$RESTIC_USER/restic
sudo cp -r $SOURCE_CONFIG_FOLDER/restic/conf/* /home/$RESTIC_USER/restic/conf/
echo_yellow "Copying scripts"
sudo mkdir -p /home/$RESTIC_USER/restic/scripts
sudo cp -r $SOURCE_CONFIG_FOLDER/restic/scripts/* /home/$RESTIC_USER/restic/scripts/
echo_yellow "Setting permissions"
sudo chown $RESTIC_USER:$RESTIC_USER /home/$RESTIC_USER
sudo chown root:$RESTIC_USER /home/$RESTIC_USER/bin/restic
sudo chown -R $RESTIC_USER:root /home/$RESTIC_USER/restic/conf
sudo chown -R $RESTIC_USER:root /home/$RESTIC_USER/restic/scripts
sudo chmod -R 640 /home/$RESTIC_USER/restic/conf/*
sudo chmod -R 740 /home/$RESTIC_USER/restic/scripts/*
sudo usermod -a -G $RESTIC_HDD_GROUP $RESTIC_USER
sudo mkdir -p $RESTIC_BACKUP_DIRECTORY
sudo chown $RESTIC_USER:$RESTIC_HDD_GROUP $RESTIC_BACKUP_DIRECTORY
echo
echo_green "---------------------------------------"
echo_green "\tInstallation complete"
echo_green "---------------------------------------"
echo
echo_yellow "Don't forget to initialize the repo"
echo
