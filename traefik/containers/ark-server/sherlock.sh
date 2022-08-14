#!/usr/bin/env bash

check_container_state() {
    local check
    check=$(docker ps -a | grep "ark-server" | grep "Exited")
    if [[ "$check" == *"Exited"* ]]; then
        echo 0
    else
        echo 1
    fi
}

check_server_state() {
    local check
    check=$( (docker exec ark-server arkmanager status | grep 'running') 2>/dev/null)
    if [[ "$check" == *"No"* || -z "$check" ]]; then
        echo 0
    else
        echo 1
    fi
}

launch_server() {
    local container_state, server_state
    container_state=$(check_container_state)
    server_state=$(check_server_state)

    if [[ "$container_state" == "0" ]]; then
        docker start ark-server >/dev/null 2>&1
    elif [[ "$server_state" == "1" ]]; then
        echo "The server is already running."
    else
        docker exec ark-server arkmanager start >/dev/null 2>&1
    fi
}

check_empty() {
    local players
    players=$(docker exec ark-server arkmanager status | grep 'Players')

    if [[ "$players" == *"Players: 0 /"* ]]; then
        echo "The server is empty."
    elif [[ -z "$players" ]]; then
        echo "The server is starting."
    else
        (docker exec ark-server arkmanager rconcmd 'listPlayers' | tail -n +3 | head -n -1 | cut -d " " -f 2-) 2>/dev/null
    fi
}

backup() {
    local backup
    backup=$(docker exec ark-server arkmanager backup | grep 'Compressing Backup' | grep 'OK')

    if [[ -n "$backup" ]]; then
        echo "Backup created !"
    else
        echo "An error occured while backuping the server !"
    fi
}

check_update() {
    local builds, current, available
    builds=$(docker exec ark-server arkmanager checkupdate | tail +3 | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" | sed "s/[^0-9]*//g" | xargs -I {} echo {})
    current=$(echo "$builds" | cut -d ' ' -f 1)
    available=$(echo "$builds" | cut -d ' ' -f 2)

    echo "- Current version: $current"
    echo "- Available version: $available"
    if [[ "$current" == "$available" ]]; then
        echo "Your server is up to date !"
    else
        echo "Your server needs to be restarted in order to receive the latest update."
    fi
}

update() {
    local server_state
    server_state=$(check_server_state)

    if [[ "$server_state" == "1" ]]; then
        echo "Please stop the server before starting the update."
    else
        local update
        update=$(docker exec ark-server arkmanager update | tail -n 1)

        if [[ "$update" == "Performing ARK update"* ]]; then
            local build
            build=$(echo "$update" | sed "s/[^0-9]*//g")
            echo "Update to build **${build}** complete !"
        else
            echo "The server is already up to date."
        fi
    fi
}

arkmanager_cmd() {
    local container_state, server_state
    container_state=$(check_container_state)
    server_state=$(check_server_state)

    if [[ "$container_state" == "0" ]]; then
        echo "The container is not running."
    elif [[ "$server_state" == "0" ]]; then
        echo "The server is not running."
    else
        eval "$*"
    fi
}

container_cmd() {
    local container_state
    container_state=$(check_container_state)

    if [[ "$container_state" == "0" ]]; then
        echo "The container is not running."
    else
        eval "$*"
    fi
}

case $1 in

"start")
    launch_server
    ;;

"stop")
    arkmanager_cmd "docker exec ark-server arkmanager saveworld" >/dev/null 2>&1
    arkmanager_cmd "docker exec ark-server arkmanager stop > /dev/null 2>&1"
    ;;

"listPlayers")
    arkmanager_cmd check_empty
    ;;

"backup")
    container_cmd "docker exec ark-server arkmanager saveworld" >/dev/null 2>&1
    container_cmd backup
    ;;

"chkupdate")
    container_cmd check_update
    ;;

"update")
    container_cmd update
    ;;

*)
    arkmanager_cmd "docker exec ark-server arkmanager status | grep 'Server running\|Server listening\|Server Name\|Players\|Server online\|Server build ID' | sed -r 's/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g' | xargs -I {} echo {}"
    ;;

esac
