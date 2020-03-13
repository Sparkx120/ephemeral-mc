# Ephemeral-MC
##### Version 0.1.0
##### MIT (c) 2020 SparkX120

This project aims to make it fast and simple to instantiate a transient minecraft server from your command line straight into the cloud of your choice with automated workd file backup. Currently only DigitalOcean is supported but plans are in place to develop support for many more clouds by migrating the core functionality of the script into a terraform script.

## How to use
This script is meant to be used as a shell library. It provides several functions to operate your server. Currently the prerequistes are as follows:

### Prerequisties
- doctl - you must login before using this scripts functions
- sshkeys - you must have an ssk key installed in `~/.ssh/id_rsa`

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
- Implement tests using BATS
- Switch to terraform to instantiate and delete servers to allow a much broader amount of cloud coverage
- Support Cloud Object Storage as an option to store the world file archives when stopping
- Support incremental backup during runtime for long running servers
- Look into options to create VM Images on Digital Ocean to make startup and shutdown faster
- Add configurable options for VM Host type and size (terraform can help here too)
- Add more configurable options to the server (an associative array may work so we can just use all options supported by the underlying docker container
- Generic SSH Key support


