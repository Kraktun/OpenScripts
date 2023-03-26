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

nginx_copy_certs() {
    # copy certs to user provided dir
    # e.g. nginx_copy_certs /src/path/to/certs /dst/path/to/cert
    # note: source_dir must contain a folder with fullchain and privkey for every site
    # i.e. /src/path/to/certs/my_site.com/fullchain.pem
    local m_source_dir=$1
    local m_dest_dir=$2
    for site_dir in $m_source_dir/*/; do
        m_local_cert=$(basename $site_dir)
        mkdir -p $m_dest_dir/$m_local_cert
        sudo cp -R $site_dir* $m_dest_dir/$m_local_cert/
        sudo chown -R root:root $m_dest_dir/$m_local_cert
        sudo chmod 0644 $m_dest_dir/$m_local_cert/fullchain.pem
        sudo chmod 0600 $m_dest_dir/$m_local_cert/privkey.pem
    done
}
