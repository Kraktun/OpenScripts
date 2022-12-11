#!/bin/bash

nginx_copy_sites_config() {
    # copy config file to nginx default dir
    local source_nginx_config=$1
    for filename in $source_nginx_config/*.conf; do
        echo "Copying $filename"
        sudo cp $filename /etc/nginx/sites-available/
        sudo chmod 0644 /etc/nginx/sites-available/$(basename $filename)
        sudo ln -s /etc/nginx/sites-available/$(basename $filename) /etc/nginx/sites-enabled/
    done
}