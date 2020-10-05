# bootstrapper
Bootstrapper to setup various work environments and to spin up a new flightcontroller.\
Hacky might be be an understatement.

## usage
./go.sh bootstrap raspberry (connects to raspberry and sets it up)\
./go.sh bootstrap raspberry-microsd (downloads and verifies distribution, then writes it to sdcard)\
./go.sh bootstrap arduino (upload firmware locally and remotely)\
./go.sh bootstrap arduino-env (sets up arduino build environment)\
./go.sh help\
./go.sh reset\
./go.sh clean
