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
  Version 0.1.1

  Script Usage:
    -s --start-mc-world <world_name>
    -t --stop-mc-world <world_name>
    -a --accept-eula 
    -k --ssh-key <ssh-key-name> (default id_rsa)

  Library Usage:
  start-mc-world <world name>
  stop-mc-world
  watch-mc-world-logs-over-ssh

  Shell Variables in Library
  SSH_KEY
  ACCEPT_EULA
EOF
)"
SSH_KEY="id_rsa"
ACCEPT_EULA=false

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
        export DO_SSH_KEYS="--ssh-keys `ssh-keygen -l -E md5 -f ~/.ssh/$SSH_KEY.pub | awk '{print $2}' | sed \"s/....//\"`"
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
/bin/bash /data/run-mc.sh $MC_NAME
EOF
}

_stop_mc_server_over_ssh() {
    MC_ARCHIVE="$MC_NAME-`_mc_world_timestamp`.tar.gz"
    ssh root@$DROP_IP << EOF
cd /
docker stop mc
tar -zcvf $MC_ARCHIVE /data
EOF
    _recv_mc_archive
}

_create_server() {
    _set_server_default_vars
    _create_droplet_blocking ephemeral-$1
    
    until netcat -z $DROP_IP 22; do
        echo "Waiting for MC Server SSH Startup"
        sleep 1
    done
    
    # TODO replace this with a proper ssh check
    ssh-keyscan -H $DROP_IP >> ~/.ssh/known_hosts
}

_delete_server() {
    _delete_droplet ephemeral-$1 
}

_create_new_mc_world() {
    echo "Creating a new world $1"
    MC_NAME=$1
    MC_ARCHIVE="$MC_NAME-`_mc_world_timestamp`.tar.gz"

    if [[ "$ACCEPT_EULA" == "false" ]]; then
        echo "You have not accepted Minecraft's Eula, you must do so before this script can create a server"
        exit 1
    fi

    # Init    
    mkdir -p mc-worlds/$MC_NAME
    cd mc-worlds/$MC_NAME
    
    # Create new blank archive file    
    mkdir data
    cp ../../lib/run-mc.sh data/
    cp ../../lib/env.sh data/    
    tar -zcf $MC_ARCHIVE data
    rm -rf data
    
    _create_server $MC_NAME
    _exec_mc_server_over_ssh
    cd - 
}

_start_existing_mc_world() {
    echo "Staring existing world $1"
    MC_NAME=$1

    # Init    
    cd mc-worlds/$MC_NAME
    MC_ARCHIVE=`mc_get_newest_archive`

    _create_server $MC_NAME
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
    if [[ -z "$MC_NAME" ]];then
        if [[ -z "$1" ]]; then
            echo "You Must provide a server name since there is no server being managed by this subshell right now!"
            return -1
        fi
        MC_NAME=$1
        DROP_IP=`_get_droplet_ip_by_regex $MC_NAME`
    fi
    cd mc-worlds/$MC_NAME
    _stop_mc_server_over_ssh
    cd -
    _delete_server $MC_NAME
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
    START_MC=false
    STOP_MC=false
    while [[ -n "$@" ]]; do
      if [[ "$1" == "--start-mc-world" ]] || [[ "$1" == "-s" ]]; then
          shift
          START_MC=true
          INIT_NAME=$1
      elif [[ "$1" == "--stop-mc-world" ]] || [[ "$1" == "-t" ]]; then
          shift
          STOP_MC=true
          INIT_NAME=$1
      elif [[ "$1" == "--accept-eula" ]] || [[ "$1" == "-a" ]]; then
          ACCEPT_EULA=true
      elif [[ "$1" == "--ssh-key" ]] || [[ "$1" == "-k" ]]; then
          shift
          SSH_KEY=$1
      elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
          echo "$USAGE"
      else
          echo "$USAGE"
          exit 1
      fi
      shift 
    done
    
    if $START_MC; then
        start-mc-world $INIT_NAME
    fi

    if $STOP_MC; then
        stop-mc-world $INIT_NAME
    fi
fi

