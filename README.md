# Aetherial-MC
This project aims to make it fast and simple to instantiate a minecraft server from your command line straight into the cloud of your choice. Currently only DigitalOcean is support but plans are in place to develop support for many more clouds by migrating the core functionality of the script functionality into terraform.

The Script currently works by creating a small archive with a startup script for an ubuntu vm to nsitall everything needed to run a dockerized instance of MineCraft's server. An environment file locally is sent with it to configure the server to your liking. When you are finished with your server the shutdown function will backup the server's data directory and environment files and brnig them back to your computer so you can easilly start the server back up again later without having to run it all the time.

This script is great for use with service such as digital ocean that bill hourly since you can get fairly cheap VM time for this price. If you don't mind the thrill you could even run it on a premptive instance in Google for ultra cheap.

## How to use
This script is meant to be used as a shell library. It provides several functions to operate your server. Currently the prerequistes are as follows:

### Prerequisties
- doctl - you must login before using this scripts functions

### Usage
```bash
source launch.sh
```

edit the env.sh and fill in your desired fields and set EULA=TRUE if you accept the Minecraft License

Start the world:
```bash
start_mc_world <world_name>
```

Stop the world:
```bash
stop_mc_world
```

After the world stops it will be archived in a folder called mc-worlds/<world_name>
When you run the `start_mc_world` command again it will automatically select the newest archive and send that to the server.

## Future Plans
- Switch to terraform to instantiate and delete servers to allow a much broader amount of cloud coverage
- Support Cloud Object Storage as an option to store the world file archives when stopping
- Support incremental backup during runtime for long running servers
- Look into options to create VM Images on Digital Ocean to make startup and shutdown faster
- Add configurable options for VM Host type and size (terraform can help here too)
- Add more configurable options to the server (an associative array may work so we can just use all options supported by the underlying docker container


