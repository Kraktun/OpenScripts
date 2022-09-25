# Linux scripts

Collection of bash scripts for common apps installation.

## Libs

This script contains a set of useful functions for different purposes. E.g. if you need to download only this folder rather than the whole repository you can use `git_clone_folder`.

## Apps

### ffmpeg

ffmpeg install script from source that currently supports only two architectures and a predefined set of libraries.
Currently downloads the git repositories every time it is run.

### Nut client

Script to install [Nut](https://networkupstools.org/) as a client (server version will be available soon).
The client is configured to shutdown when the ups runs on battery either after a timer or when the battery is low.
The script also configures a service to send an email when the ups runs on battery.

An example of `msmtprc` file can be found [here](https://wiki.debian.org/msmtp) and the `control_script.sh` file can be something like this

```bash
#!/bin/bash

case $1 in
    onbattshutdown)
        printf "Subject: UPS Notification\n\nShutting down server in 1 minute\nFrom IP: `hostname -I | awk '{print $1}'` \nHOST: `hostname` \nTime: `TZ=Europe/Rome date`" | msmtp MY_EMAIL_ADDRESS@EXAMPLE.COM
        sudo shutdown -h +1
            ;;
    onbattshutdownnow)
        printf "Subject: UPS Notification\n\nLOW BATTERY ALERT \nShutting down server now\nFrom IP: `hostname -I | awk '{print $1}'` \nHOST: `hostname` \nTime: `TZ=Europe/Rome date`" | msmtp MY_EMAIL_ADDRESS@EXAMPLE.COM
        sudo shutdown -h +0
            ;;
    onbattwarn)
        printf "Subject: UPS Notification\n\nUps is running on battery \nFrom IP: `hostname -I | awk '{print $1}'` \nHOST: `hostname` \nTime: `TZ=Europe/Rome date`" | msmtp MY_EMAIL_ADDRESS@EXAMPLE.COM
            ;;
    *)
        logger -t upssched-cmd "Unrecognized command: $1"
            ;;
esac
```

### Rclone client

Script to install [rclone](https://rclone.org/) as a client. The configuration is such that a single server exposes a limited sftp service so that multiple clients can connect to it and upload their files in predefined directories. Authentication is based on keys.

This script should be run only after the server has been configured with `rclone_server.sh`.

### Rclone server

Script that configures a user with limited privileges and a folder where the clients can upload their files.

### Restic

Script to install [restic](https://restic.net/) and configure a single user to control it.
The script also copies `conf` and `scripts` folders that should contain the configuration and scripts to run restic.

Config files should contain your repository passwords and accounts (properly protected) and filter options. Note that this is not mandatory and those lines can be removed from the script.
