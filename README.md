# ROS bootstrapper
Bootstrapper to setup various work environments and to spin up a new flightcontroller.

## usage
#### to connect to a raspberry and sets it up idempotently
./go.zsh bootstrap raspberry
#### to download and verify distribution and to write it to an sdcard
./go.zsh bootstrap raspberry-microsd
#### to upload firmware locally or remotely
./go.zsh bootstrap arduino
#### to set up arduino build environment
./go.zsh bootstrap arduino-env
#### to create an accesspoint (works only on an Arch Linux flavoured systems)
./go.zsh create accesspoint
#### to shell into to raspberry as admin user
./go.zsh shell
#### to pull in all dependencies
./go.zsh dependencies
#### to display help
./go.zsh help
#### to remove all configurations and keys
./go.zsh reset
#### to remove replacable files (like downloads)
./go.zsh clean
