# bootstrapper
Bootstrapper to setup various work environments and to spin up a new flightcontroller.\
Hacky might be be an understatement.

## usage
./go.zsh bootstrap raspberry (connects to raspberry and sets it up)\
./go.zsh bootstrap raspberry-microsd (downloads and verifies distribution, then writes it to sdcard)\
./go.zsh bootstrap arduino (upload firmware locally and remotely)\
./go.zsh bootstrap arduino-env (sets up arduino build environment)\
./go.zsh create accesspoint (works only on Arch)\
./go.zsh dependencies (attempts to pull in all dependencies)\
./go.zsh help\
./go.zsh reset\
./go.zsh clean
