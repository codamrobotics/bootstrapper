#!/bin/zsh
#
# Configurations go into config.txt
#

# internal environment variables
set -a
kernel="$(uname -s)"
callee=$0
source $(dirname "$0")/lib/core.zsh
basedir=$(realpath $(dirname "$0"))
lib=$basedir/lib
playbooks=$basedir/playbooks
ssh_d=$basedir/.ssh
configcache=$basedir/.config
configtemplate=$lib/config.template
refresh=$basedir/.refresh
downloads=$basedir/downloads
os_img=$downloads/$OS_IMG
os_img_checksum=$os_img.sha256sums
os_mnt=$basedir/.mnt
source $lib/checks.zsh || exit 1
source $lib/image.zsh || exit 1
source $lib/firmware.zsh || exit 1
source $lib/create_ap.zsh || exit 1
source $basedir/config.txt || exit 1

# internal runtime variables
banner=false

## os variables
case $kernel in
	Darwin)
		alias PKG_UPDATE="brew update"
		alias PKG_INSTALL="brew install"
	;;
	Linux)
		os_flavour=$(cat /etc/os-release | grep ID_LIKE | cut -d= -f2)
		case $os_flavour in
			arch)
				alias PKG_UPDATE="yay -Sy"
				alias PKG_INSTALL="yay -S"
			;;
			ubuntu)
				alias PKG_UPDATE="sudo apt-get update"
				alias PKG_INSTALL="sudo apt-get install -y"
			;;
			*) logp usage "You have choosen an operating system that is not on good terms with the Federation." ;;
		esac
	;;
	*) logp usage "You have choosen an operating system that is not on good terms with the Federation." ;;
esac
# end of environment variables

function clean_up()
{
	[ ! -f $basedir/.tmp ] || rm -f $basedir/.tmp
	[ ! -z "$(mount | grep $os_mnt)" ] && logp info "Unmounting $os_mnt" && sudo umount $os_mnt && rmdir $os_mnt
	case $1 in
		INT) logp fatal "The button of death has entered the room." ;;
		EXIT) [ $banner = true ] && logp endsection ;;
		TERM) logp fatal "The program seizes to live." ;;
	esac
}

trap "clean_up INT" INT
trap "clean_up TERM" TERM
trap "clean_up EXIT" EXIT

function banner()
{
	banner=true
	clear

	case $kernel in 
		Darwin) PRETTY_NAME="Mac OSx" ;;
		Linux) source /etc/os-release ;;
	esac
	cols=$(tput cols)
	date=$(date)
	whoami=$(whoami)
	ip="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | tail -n1)"
	beacon="$(whoami)@$HOST ($ip)"
	zsh -c "echo -e \"\e[1m\e[33m+$(termFill '-' $((cols - 2)))+\""
	printf "|\e[0m`tput bold` %-$((cols - $((15 + ${#PRETTY_NAME} + ${#beacon})) ))s%-5s\e[1m\e[33m |\n" "$callee -- ROS:$ROS_RELEASE" "running $PRETTY_NAME @ $beacon"
	printf "\e[1m\e[33m| %-$((cols - 4))s\e[1m\e[33m |\n" ""
	if [ $# -gt 0 ]; then; printf "\e[1m\e[33m| %-$((cols - $((4 + ${#date})) ))s%-5s\e[1m\e[33m |\n" "$1" "`date`"; fi
	logp beginsection	
}

function prepareAdminEnvironment()
{
	[ ! -d $ssh_d ] && mkdir -p $ssh_d
	if [ ! -f $ADMIN_KEY ]; then
		logp info "Generating sshkey $ADMIN_KEY"
		prepareDependency ssh-keygen
		ssh-keygen -f $ADMIN_KEY -q -N "" || logp fatal "Couldn't generate ansible's bloody key!"
	fi
}

function prepareAnsibleEnvironment()
{
	prepareDependency ansible
	[ ! -d $ssh_d ] && mkdir -p $ssh_d

	ANSIBLE_USER=ansible
	ANSIBLE_KEY=$(realpath $ssh_d)/ansible
	if [ ! -f $ANSIBLE_KEY ]; then
		logp info "Generating sshkey $ANSIBLE_KEY"
		prepareDependency ssh-keygen
		ssh-keygen -f $ANSIBLE_KEY -q -N "" || logp fatal "Couldn't generate ansible's bloody key!"
	fi
}

function ansibleRunPlaybook
{
	target=$1
	if [ $# -eq 2 ] && [ "$2" = "firstrun" ]; then
		ansibleoptions="ansible_port=$RPORT ansible_ssh_user=$DEFAULT_USER ansible_ssh_pass=$DEFAULT_PASS ansible_python_interpreter=/usr/bin/python3"
	else
		[ ! -f $ANSIBLE_KEY ] && logp fatal "No ansible ssh key found."
		ansibleoptions="ansible_port=$RPORT ansible_ssh_user=$ANSIBLE_USER ansible_ssh_private_key_file=$ANSIBLE_KEY ansible_python_interpreter=/usr/bin/python3 "
	fi

	ansible-playbook	-i $RHOST,\
						-e $ansibleoptions \
						$basedir/playbooks/$target.yml 
}

function readConfigcache() { export $(grep -f $configtemplate $configcache) }

function writeConfigcache() { env | grep -f $configtemplate > $configcache }

function getUserInfo()
{
	checkConfigcacheExists $configcache  && { readConfigcache || logp fatal "configfile' $configfile' has corrupted." }

	case $ACTION in 
		bootstrap)
			case $2 in
				raspberry)
					{ [ ! -f $configcache ] || [[ $(wc -l $configcache | sed -e 's/^[[:space:]]*//' | cut -f1 -d\ ) -lt 3 ]] } && logp info "Your attention is required. The experiment requires you to answer truely and wholeheartedly."
					[ -z "${RHOST+x}" ] && logp question "remote host's network address" && read -r RHOST
					[ -z "${RPORT+x}" ] && logp question "remote host's port" &&  read -r RPORT
					[ -z "${RHOSTNAME+x}" ] && logp question "remote host's hostname" &&  read -r RHOSTNAME
					[ -z "${DEFAULT_USER+x}" ] && logp question "remote host's first login user" && read -r DEFAULT_USER
					[ -z "${DEFAULT_PASS+x}" ] && logp question "remote host's first login  pass" && read -r DEFAULT_PASS
				;;
				raspberry-microsd)
					logp info "Your attention is required. The experiment requires you to answer truely and wholeheartedly."
					if which lsblk; then
						logp info "Block devices : "
						lsblk -f 
					fi
					logp question "Destination microsd card (or other blockdevice)" && read -r blk_dev
					[ -z "${WIFI_SSID+x}" ] && logp question "Wifi address" && read -r WIFI_SSID
					[ -z "${WIFI_PASS+x}" ] && logp question "Wifi password" && read -r WIFI_PASS
				;;
				*) logp fatal "CRASH @ getUserInfo" ;;
			esac
		;;
		run)
			case $2 in
				playbook)
					[ -z "${RHOST+x}" ] && logp question "remote host's network address" && read -r RHOST
				;;
				*) logp fatal "CRASH @ getUserInfo" ;;
			esac
		;;
		create)
			case $2 in
				accesspoint)
					[ -z "${WIFI_SSID+x}" ] && logp question "Wifi address" && read -r WIFI_SSID
					[ -z "${WIFI_PASS+x}" ] && logp question "Wifi password" && read -r WIFI_PASS
					[ -z "${WIFI_DEV+x}" ] && { which ifconfig && ifconfig || true } && logp question "Wifi device" && read -r WIFI_DEV
				;;
				*) logp fatal "CRASH @ getUserInfo" ;;
			esac
		;;
		shell)
			{ [ ! -f $configcache ] || [[ $(wc -l $configcache | sed -e 's/^[[:space:]]*//' | cut -f1 -d\ ) -lt 3 ]] } && logp info "Your attention is required. The experiment requires you to answer truely and wholeheartedly."
			[ -z "${RHOST+x}" ] && logp question "remote host's network address" && read -r RHOST
			[ -z "${RPORT+x}" ] && logp question "remote host's port" &&  read -r RPORT
		;;
		*) logp fatal "CRASH @ getUserInfo" ;;
	esac

	writeConfigcache
}

function prepareDependency()
{
	dep=$1
	if ! command -v $dep &> /dev/null; then
		logp info "Dependency '$dep' is missing. Attempting to install:"
		PKG_UPDATE || logp fatal "Couldn't update from repositories"
		PKG_INSTALL $dep || logp fatal "Couldn't install dependency '$dep'!"
	fi
}

function prepareAllDependencies()
{
	U=0
	for dep in "${DEPENDENCIES[@]}"
	do
		if ! command -v $dep &> /dev/null; then
			if [ $U -eq 0 ]; then
				PKG_UPDATE || logp fatal "Couldn't update packages"
				U=1
			fi
			PKG_INSTALL $dep || logp fatal "Couldn't install dependency '$dep'!"
		fi
	done
	logp info "All dependencies were met."
}

#https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
function pullMaster()
{
	logp info "Checking for update.."
	prepareDependency git
	if git remote update 1>/dev/null ; then
		upstream=${1:-'@{u}'}
		local=$(git rev-parse @ $basedir)
		remote=$(git rev-parse "$upstream" $basedir)
		if [ $local != $remote ]; then
			p=$(pwd)
			cd $basedir
			git pull 1>/dev/null
			git submodule update --init --remote 1>/dev/null
			logp info "Bootstrapper has evolved!"
			cd $p
		fi
	else; return 1; fi
}

function prepareEnvironment()
{
	[ "$(echo $SHELL | rev | cut -d\/ -f1 | rev)" = "zsh" ] || logp fatal "$callee requires to be run with zsh."
	checkConnectivity && checkMasterUpdate && { pullMaster || logp warning "An update has failed you. Your computer will explode now." } || true
}

function handleFlags()
{
	[ $# -eq 0 ] && usage
	# read action options
	for ARG in $@; do
		[ "${ARG}" = "bootstrap" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "run" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "create" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "dependencies" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "shell" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "clean" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "reset" ] && ACTION="${ARG}" && break
		[ "${ARG}" = "help" ] && ACTION="${ARG}" && break
	done
	[ "$ACTION" = "" ] && usage
}

function performActions()
{
	case $ACTION in
		bootstrap) #############################################################
			[ $# -lt 2 ] && logp usage "$callee bootstrap [raspberry | arduino | arduino-env ] [ARGS]"
			case $2 in
				raspberry) #####################################################
					banner "God looked down and agreed with this strategy. Bootstrapping raspberry.."

					getUserInfo $@	|| logp fatal "Failed to get your info"

					checkConnectivity || logp fatal "The network doesn't believe you have connected to it."
					checkIsReachable $RHOST || logp fatal "Host '$RHOST' is not reachable at this time (ping test)."
					prepareAnsibleEnvironment || logp fatal "The Ansible Environment has denied your request."
					prepareAdminEnvironment || logp fatal "The Admin Environment has denied your request."

					if ! checkIsManageable $RHOST $RPORT $ANSIBLE_USER "NULL" $ANSIBLE_KEY; then
						target="ansible_user"; logp info "Started running playbook $target...";
						ansibleRunPlaybook $target firstrun || logp fatal "The machine is still resisting. $target rules have failed to comply!"
						if checkIsManageable $RHOST $RPORT $DEFAULT_USER $DEFAULT_PASS; then
							target="lock"; logp info "Started running playbook $target...";
							ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"
						else 
							logp fatal "Your $RHOST gave us trouble. Please give us the right credentials."
						fi
						sleep 5 # lock fucks with ssh-server
					fi

					target="disable-unattended-upgrades"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					target="system"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					target="firewall"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					export NUSER="$ADMIN_USER" NKEY="$ADMIN_KEY" NGROUPS="$ADMIN_GROUPS"
					target="user"; logp info "Started running playbook $target for user '$NUSER'...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					target="firmware"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					target="ros"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					logp info "The machine has spoken. Bootstrap complete."
				;;
				raspberry-microsd) #############################################
					banner "Electrons! We summon you to carry out this microsd bootstrapping thing!"

					getUserInfo	$@ || logp fatal "Failed to get your info"
					image_prepare || logp fatal "Image couldn't be prepared at this moment."
					image_write || logp fatal "Failed to write image."
					logp info "The image was written succesfully." 

					firmware_prepare_network || logp fatal "Failed to apply network information: enter network info manualy!"
					firmware_prepare_bootloader || logp fatal "Failed preparing bootloader."
					logp info "The network configuration has decided in favour of the Federation. It was a wise decision." 

					[ ! -z "$(mount | grep $os_mnt)" ] && logp info "Unmounting $os_mnt" && { sudo umount $os_mnt || logp warning "Failed unmounting $os_mnt" }
					logp info "Syncing last blocks to disk.." && sudo sync
					logp info "By the analog Gods and the digital! The image was build. Yalla let us bootstrap a raspberry."
				;;
				arduino) #######################################################
					banner "Arduino here to bootstrap your spine."

					[ ! -f $ARDUINO_FIRMWARE_LOCATION ] && logp fatal "Store the compiled arduino firmware file @ $ARDUINO_FIRMWARE_LOCATION"

					getUserInfo	$@ || logp fatal "Failed to get your info"

					logp question "Local or Remote ? -> type L or R : "; read -r response
					if [ "$response" = "L" ]; then
						logp info "Attempting to flash locally.."

					elif [ "$response" = "R" ]; then
						logp info "Attempting to flash remotely.."
						checkIsReachable $RHOST || logp fatal "Host '$RHOST' is not reachable at this time (ping test)."
						
						target="arduino_upload"; logp info "Started running playbook $target...";
						ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					else
						logp fatal "bekijk 't maar"
					fi
				;;
				arduino-env) ###################################################
					[ ! $# -eq 3 ] && logp usage "$callee bootstrap arduino-env [[HOST:DIRECTORY] | [DIRECTORY]]"
					if checkIsReachable "$(echo $3 | cut -d: -f1)"; then
						which rsync || logp fatal "Cannot copy to/from host without rsync installed!"
						rsync -Wav --progress $3 || logp fatal "Couldn't copy arduino env over"
					elif [ -d $3 ] || mkdir -p $3; then
						dir=$3
						PKG_INSTALL $ARDUINO_PACKAGES || logp fatal "Couldn't install Arduino packages!"
						git clone git@github.com:$GIT_ORG/$GIT_LLC.git $dir || logp fatal "Couldn't clone Arduino-env!"
					else
						logp usage "$callee bootstrap arduino-env [[HOST:DIRECTORY] | [DIRECTORY]]";
					fi
				;;
				*) logp usage "You have choosen an option that is not on good terms with the Federation." ;;
			esac
		;;
		run) ###################################################################
			[ $# -lt 2 ] && logp usage "Run where?"
			case $2 in
				playbook)
					[ $# -lt 3 ] && logp usage "Run what playbook? \n\n$(cd $playbooks && print -rl -- *.yml(:r)) "
					[ -f $playbooks/$3.yml ] || logp usage "Playbook $3 not found in $playbooks"

					ANSIBLE_KEY=$(realpath $ssh_d)/ansible
					ANSIBLE_USER=ansible
					[ -f $ANSIBLE_KEY ] || logp fatal "No ansible key -> Bootstrap raspberry first."

					banner "Playbook '$3' running.."

					getUserInfo $@	|| logp fatal "Failed to get your info"

					checkConnectivity || logp fatal "The network doesn't believe you have connected to it."
					checkIsManageable $RHOST $RPORT $ANSIBLE_USER "NULL" $ANSIBLE_KEY || logp fatal "Host $RHOST is not talkative at the moment."
					target="$3"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					logp info "The playbook has come to a conclusion."
				;;
				*) logp usage "You have choosen an option that is not on good terms with the Federation." ;;
			esac
		;;
		create) ################################################################
			case $2 in
				accesspoint)
					[ "$kernel" = "Linux" ] && [ "$os_flavour" = "arch" ] || logp fatal "This function depends on AUR package create_ap. Since you are not running a flavour of Arch Linux I canno't help you. Setup a wifi accespoint manually."
					which create_ap || which yay || logp fatal "I don't know how to get create_ap from the AUR. Do you have 'yay' installed? If not install it and run again, or get a hold of 'create_ap' yourself."

					banner "The Federation has sent you an accesspoint."
					getUserInfo	$@ || logp fatal "Failed to get your info"
					create_accesspoint || logp fatal "Killed."
				;;
				*) logp usage "You have choosen an option that is not on good terms with the Federation." ;;
			esac
		;;
		shell) #################################################################
			getUserInfo	$@ || logp fatal "Failed to get your info"
			[ -f $ADMIN_KEY ] || logp fatal "You have to bootstrap the raspberry first, to set the key."
			{ [ -z "${RPORT+x}" ] || [ -z "${RHOST+x}" ] || [ -z "${ADMIN_USER+x}" ] || [ -z "${ADMIN_KEY+x}" ] } && logp fatal "Crash! Variables not set."
			ssh -p $RPORT -o PreferredAuthentications=publickey -i $ADMIN_KEY $ADMIN_USER@$RHOST
			[ $? -eq 130 ] || logp fatal "Shell couldn't be attained."
		;;
		dependencies) #######################$##################################
			prepareAllDependencies || logp fatal "Missing dependencies."
		;;
		clean) #################################################################
			[ -f $ARDUINO_FIRMWARE_LOCATION ] && rm -f $ARDUINO_FIRMWARE_LOCATION && logp info "Cleaned configcache '$ARDUINO_FIRMWARE_LOCATION'"
			[ -d $downloads ] && rm -rf $downloads && logp info "Cleaned out downloads folder : $downloads."
		;;
		reset) #################################################################
			logp warning_nnl "Are you sure? This will also delete ansible/user keys! -> Legal demands that you type IMNOTANIDIOT to continue : "; read -r response
			if [ "$response" = "IMNOTANIDIOT" ]; then
				[ -d "$ssh" ] && rm -rf $ssh && logp info "Cleaned ssh folder with keys '$ssh'"
				[ -f $refresh ] && rm -f $refresh && logp info "Cleaned git update refresh file '$refresh'"
				[ -f $configcache ] && rm -f $configcache && logp info "Cleaned configcache '$configcache'"
				[ -f $ARDUINO_FIRMWARE_LOCATION ] && rm -f $ARDUINO_FIRMWARE_LOCATION && logp info "Cleaned configcache '$ARDUINO_FIRMWARE_LOCATION'"
				[ -d $downloads ] && rm -rf $downloads && logp info "Cleaned out downloads folder : $downloads."
			else	logp fatal "Probably a wise decision."; fi
		;;
		help|*) ################################################################
			usage
		;;
	esac
}

function usage()
{
	(logp usage "")
	cat<<-EOF
		$callee bootstrap	raspberry
		$callee bootstrap	raspberry-microsd
		$callee bootstrap	arduino
		$callee bootstrap	arduino-env

		$callee run		playbook		[playbook]

		$callee create		accesspoint

		$callee shell

		$callee dependencies # pull in dependencies

		$callee clean # deletes replaceable data
		$callee reset # this clears out more than you might want

		$callee help 
	EOF
	exit 1
}

function main()
{
	prepareEnvironment || logp fatal "The Environment has denied your request."
	handleFlags $@
	performActions $@
}

main $@
