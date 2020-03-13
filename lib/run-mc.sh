#!/bin/bash
##
# Run-MC
# A script to detect and install docker then run a Minecraft Server
# This script assumes an Ubuntu Environment
#
# @version 0.1.1
# @author SparkX120
# @licence MIT
##

# TODO Move all settings into environment
source /data/env.sh $1

# Install Docker if its missing
if [[ -z `which docker` ]]; then
  apt -y update
  apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  apt update
  apt -y install docker-ce docker-ce-cli containerd.io
fi

docker run -d --rm -v /data:/data -d -p 25565:25565 \
	-e EULA=$EULA \
	-e MOTD="$MOTD" \
	-e SERVER_NAME=$NAME \
	-e DIFFICULTY=$DIFFICULTY \
	-e MODE=$MODE \
	-e OPS=$OPS \
	-e INIT_MEMORY=$INIT_MEMORY \
	-e MAX_MEMORY=$MAX_MEMORY \
	-e ENABLE_RCON=$ENABLE_RCON \
	--name mc \
	itzg/minecraft-server:latest

