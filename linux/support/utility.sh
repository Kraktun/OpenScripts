#!/bin/bash


get_open_ports() {
    sudo lsof -i -P -n | grep LISTEN
}

docker_list_ports() {
    sudo docker container ls --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}" -a
}

toggle_history() {
    if [[ "$0" == "$BASH_SOURCE" ]]; then
        echo "You must source this file for it to work"
        exit 1
    fi

    if [[ "$1" == "e" ]]; then
        echo "Enabling history"
        set -o history
    elif [[ "$1" == "d" ]]; then
        echo "Disabling history"
        set +o history
    else
        echo "Invalid option passed. Accepted: [e, d]"
    fi
}

