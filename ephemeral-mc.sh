#!/bin/bash
##
# Ephemeral MC 
# A script to Start a Dockerized Minecraft Server on a Digital Ocean Droplet
#
# TODO switch to terraform so we can target any cloud
#
# @version 0.1.0
# @author SparkX120
# @license MIT
##
USAGE="$(cat << EOF
  Welcome to Ephemeral MC, a shell library to manage an ephemeral minecraft world in the cloud!
  Version 0.1.0

  Usage:
  start-mc-world <world name>
  stop-mc-world
  watch-mc-world-logs-over-ssh
EOF
)"

##################################################################################
# General Utility Functions                                                      #
##################################################################################
_mc_world_timestamp() {
    date +%Y%m%d%H%M
}

mc_get_newest_archive() {
    ls -lt | head -n 2 | tail -n 1 | awk '{print $9}'
}

##################################################################################
# Utility Functions for Digital Ocean                                            #
##################################################################################

_get_droplet_id_by_regex() {
    # Gets a droplet id using a regex
    doctl compute droplet list | grep "$1" | awk '{print $1}'
}

_get_droplet_ip_by_regex() {
    # Gets a droplet ip using a regex
    doctl compute droplet list | grep "$1" | awk '{print $3}'
}

_get_droplet_status_by_regex() {
    # Gets a droplet status using a regex
    doctl compute droplet list | grep "$1" | awk '{print $11}'
}

_create_droplet_blocking() {
    # Creates a droplet and blocks until it is ready
    echo "Creating Droplet $1"
    doctl compute droplet create $1 $DO_SLUG $DO_IMAGE $DO_SSH_KEYS $DO_REGION --wait -v 
    export DROP_IP=`_get_droplet_ip_by_regex $1`
}

_delete_droplet() {
    # Deletes a droplet by name
    doctl compute droplet delete $1
}

_set_server_default_vars() {
    if [[ -z "$DO_SLUG" ]]; then    
        export DO_SLUG='--size m-2vcpu-16gb'
    fi
    if [[ -z "$DO_IMAGE" ]]; then
        export DO_IMAGE='--image 53871280'
    fi
    # TODO make this more robust for alternate ssh keys
    if [[ -z "$DO_SSH_KEYS" ]]; then
        export DO_SSH_KEYS="--ssh-keys `ssh-keygen -l -E md5 -f ~/.ssh/id_rsa.pub | awk '{print $2}' | sed \"s/....//\"`"
    fi
    if [[ -z "$DO_REGION" ]]; then
        export DO_REGION='--region nyc3'
    fi
}

##################################################################################
# Minecraft Server Control Functions                                             #
##################################################################################

_send_mc_archive() {
   scp $MC_ARCHIVE root@$DROP_IP:/
}

_recv_mc_archive() {
   scp root@$DROP_IP:/$MC_ARCHIVE .
}

_exec_mc_server_over_ssh() {
    _send_mc_archive
    ssh root@$DROP_IP << EOF
cd /
tar -zxvf /$MC_ARCHIVE
/bin/bash /data/run-mc.sh $NAME
EOF
}

_stop_mc_server_over_ssh() {
    MC_ARCHIVE="$NAME-`_mc_world_timestamp`.tar.gz"
    ssh root@$DROP_IP << EOF
cd /
docker stop mc
tar -zcvf $MC_ARCHIVE /data
EOF
    _recv_mc_archive
}

_create_server() {
    _set_server_default_vars
    _create_droplet_blocking $1
    
    
    # TODO replace this with a proper ssh check
    ssh-keyscan -H $DROP_IP >> ~/.ssh/known_hosts
}

_delete_server() {
    _delete_droplet $1 
}

_create_new_mc_world() {
    echo "Creating a new world $1"
    NAME=$1
    MC_ARCHIVE="$NAME-`_mc_world_timestamp`.tar.gz"
    
    # Init    
    mkdir -p mc-worlds/$NAME
    cd mc-worlds/$NAME
    
    # Create new blank archive file    
    mkdir data
    cp ../../lib/run-mc.sh data/
    cp ../../lib/env.sh data/
    tar -zcf $MC_ARCHIVE data
    rm -rf data
    
    _create_server $NAME
    _exec_mc_server_over_ssh
    cd - 
}

_start_existing_mc_world() {
    echo "Staring existing world $1"
    NAME=$1

    # Init    
    cd mc-worlds/$NAME
    MC_ARCHIVE=`mc_get_newest_archive`

    _create_server $NAME
    _exec_mc_server_over_ssh
    cd -
}

start-mc-world() {
    if [[ -z "$1" ]]; then
        echo "You must provide a name for your server as the first argumen to this functon!"
        return -1
    fi
    if [[ -d "mc-worlds/$1" ]]; then
        _start_existing_mc_world $1
    else
        _create_new_mc_world $1
    fi
    echo "World starting on $DROP_IP"
    echo "To view logs run watch-mc-server-logs-over-ssh"
}

stop-mc-world() {
    # Stop and archive the minecraft server currently running in this subshell
    # If for some reason you are in a new shell you can pass the name
    if [[ -z "$NAME" ]];then
        if [[ -z "$NAME" ]]; then
            echo "You Must provide a server name since there is no server being managed by this subshell right now!"
            return -1
        fi
        NAME=$1
    fi
    cd mc-worlds/$NAME
    _stop_mc_server_over_ssh
    cd -
    _delete_server $NAME
}

watch-mc-server-logs-over-ssh() {
    # Watch the minecraft servers logs over ssh
    ssh root@$DROP_IP << EOF
docker logs -f mc
EOF
}

if (return 0 2>/dev/null); then
    echo "$USAGE"
else
    echo "This script is currently only a shell library, please source it to use its functions"
fi

