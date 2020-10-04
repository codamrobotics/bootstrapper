#!/bin/zsh
#
# Configurations go into config.txt
#

# environment variables
set -a
kernel="$(uname -s)"
callee=$0
basedir=$(dirname "$0")
lib=$basedir/lib
playbooks=$basedir/playbooks
playbooks_cpy=$basedir/.playbooks_cpy
ansibleconfigcache=$basedir/.ansible.config
ansibleconfigtemplate=$lib/ansible.config.template
ssh_d=$basedir/.ssh
configcache=$basedir/.config
configtemplate=$lib/config.template
refresh=$basedir/.refresh
banner=false

## os variables
case $kernel in
	Darwin)
		alias PKG_UPDATE="brew update"
		alias PKG_INSTALL="brew install"
		;;
	Linux)
		flavour=$(cat /etc/os-release | grep ID_LIKE | cut -d= -f2)
		case $flavour in
			arch)
				alias PKG_UPDATE="yay -Sy"
				alias PKG_INSTALL="yay --noconfirm -S"
				;;
			ubuntu)
				alias PKG_UPDATE="sudo apt-get update"
				alias PKG_INSTALL="sudo apt-get install -y"
				;;
		esac
		;;
esac
# end of environment variables

function clean_up()
{
	case $1 in
		INT)
			logp fatal "aborting.."
		;;
		EXIT)
			tmp_delete
			if [ $banner = true ]; then
				logp endsection
			fi
		;;
		TERM)
			logp fatal "aborting.."
		;;
	esac
}

trap "clean_up INT" INT
trap "clean_up TERM" TERM
trap "clean_up EXIT" EXIT

function logp()
{ 
	case "$1" in
		info)
			zsh -c "echo -e \"\e[32m\e[1m* \e[0m$2\""
			;;
		info_nnl)
			zsh -c "echo -n -e \"\e[32m\e[1m* \e[0m$2\""
			;;
		usage)
			zsh -c "echo -e \"\e[32m\e[1mUsage: \e[0m$2\""
			exit 0
			;;
		question)
			zsh -c "echo -e -n \"\e[32m\e[1mUse your keyboard:  \e[0m$2 : \""
			;;
		warning)
			zsh -c "echo -e \"\033[31m\e[1m* \e[0m$2\""
			;;
		warning_nnl)
			zsh -c "echo -n -e \"\033[31m\e[1m* \e[0m$2\""
			;;
		fatal)
			zsh -c "echo -e \"\e[31m\e[1m* \e[0m\e[30m\e[101m$2\e[0m\""
			exit 1
			;;
		beginsection)
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '*')\e[0m\""
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '|')\e[0m\""
			;;
		endsection)
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '|')\e[0m\""
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '*')\e[0m\""
			;;
	esac
}

function termFill() { 
		cols=$(tput cols)
		if [ $# -gt 1 ]; then
			while [[ $x -lt $cols ]] && [[ $x -lt $2 ]]; do printf "$1"; let x=$x+1; done;
		else
			while [[ $x -lt $cols ]]; do printf "$1"; let x=$x+1; done;
		fi
}

function tmp_create()
{
	if [ -d $playbooks_cpy ]; then logp fatal "Temporary directory $playbooks_cpy already exists!"; fi
	cp -r $playbooks $playbooks_cpy || logp fatal "Couldn't setup tmp directory!"
}

function tmp_delete()
{
	if [ -f $basedir/.tmp ]; then rm -f $basedir/.tmp; fi
	if [ -d $playbooks_cpy ]; then rm -r $playbooks_cpy; fi
}

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

function usage()
{
	(logp usage "")
	cat<<-EOF
		$callee bootstrap raspberry
		$callee bootstrap arduino
		$callee bootstrap arduino-env [[HOST:DIRECTORY] | [DIRECTORY]]
		$callee clean
		$callee reset # this clears out more than you might want
		$callee help	
	EOF
	exit 1
}

function handleFlags()
{
	[ $# -eq 0 ] && usage

	# read action options
	for ARG in $@; do
		if [ "${ARG}" = "bootstrap" ]; then ACTION="${ARG}"; break; fi
		if [ "${ARG}" = "clean" ]; then ACTION="${ARG}"; break; fi
		if [ "${ARG}" = "reset" ]; then ACTION="${ARG}"; break; fi
		if [ "${ARG}" = "help" ]; then ACTION="${ARG}"; break; fi
	done
	[ "$ACTION" = "" ] && usage
}

function performActions()
{
	case $ACTION in
		bootstrap)
			[ $# -lt 2 ] && logp usage "$callee bootstrap [raspberry | arduino | arduino-env ] [ARGS]"
			case $2 in
				raspberry)
					#if [ ! $# -eq 3 ]; then logp usage "$callee bootstrap raspberry [RHOST]"; fi

					banner "Arr matey. Bootstrapping raspberry. Strike the earth!"

					if checkConfigcacheExists $configcache ; then readConfigcache || logp fatal "configfile' $configfile' has corrupted."
					else getUserInfo	|| logp fatal "Failed to get your info"; fi

					checkIsReachable $RHOST || logp fatal "Host '$RHOST' is not reachable at this time (ping test)."
					prepareEnvironment || logp fatal "The Environment has denied your request."
					prepareAnsibleEnvironment || logp fatal "The Ansible Environment has denied your request."

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

					target="system"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					target="ros"; logp info "Started running playbook $target...";
					ansibleRunPlaybook $target || logp fatal "The machine is still resisting. $target rules have failed to comply!"

					logp info "Bootstrap complete."
				;;
				arduino)
					banner "Arduino here to bootstrap your spine."

					[ ! -f $ARDUINO_FIRMWARE_LOCATION ] && logp fatal "Store the compiled arduino firmware file @ $ARDUINO_FIRMWARE_LOCATION"

					if checkConfigcacheExists $configcache ; then readConfigcache || logp fatal "configfile' $configfile' has corrupted."
					else getUserInfo	|| logp fatal "Failed to get your info"; fi

					prepareEnvironment || logp fatal "The Environment has denied your request."

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
				arduino-env)
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
			esac
		;;
		clean)
			[ -f $configcache ] && rm -f $configcache && logp info "Cleaned configcache '$configcache'"
			[ -f $ARDUINO_FIRMWARE_LOCATION ] && rm -f $ARDUINO_FIRMWARE_LOCATION && logp info "Cleaned configcache '$ARDUINO_FIRMWARE_LOCATION'"
		;;
		reset)
			logp warning_nnl "Are you sure? This will also delete ansible/user keys! -> type BADIDEA to continue : "
			read -r response
			if [ "$response" = "BADIDEA" ]; then
				[ -d "$ssh" ] && rm -rf $ssh && logp info "Cleaned ssh folder with keys '$ssh'"
				[ -f $refresh ] && rm -f $refresh && logp info "Cleaned git update refresh file '$refresh'"
				[ -f $configcache ] && rm -f $configcache && logp info "Cleaned configcache '$configcache'"
				[ -f $ARDUINO_FIRMWARE_LOCATION ] && rm -f $ARDUINO_FIRMWARE_LOCATION && logp info "Cleaned configcache '$ARDUINO_FIRMWARE_LOCATION'"
			else
				echo "N\\A"
			fi

		;;
		help)
			usage
		;;
	esac
}

function prepareAnsibleEnvironment()
{
	ANSIBLE_USER=ansible
	ANSIBLE_KEY=$(realpath $ssh_d)/ansible
	[ ! -d $ssh_d ] && mkdir -p $ssh_d
	if ! checkHasAnsibleKey && [ -z ${RKEY+x} ]; then
		ssh-keygen -f $ANSIBLE_KEY -q -N "" || logp fatal "Couldn't generate ansible's bloody key!"
	fi
}

function ansibleRunPlaybook
{
	target=$1
	if [ $# -eq 2 ] && [ "$2" = "firstrun" ]; then
		ansibleoptions="ansible_port=$RPORT ansible_ssh_user=$DEFAULT_USER ansible_ssh_pass=$DEFAULT_PASS"
	else
		[ ! -f $ANSIBLE_KEY ] && logp fatal "No ansible ssh key found."
		ansibleoptions="ansible_port=$RPORT ansible_ssh_user=$ANSIBLE_USER ansible_ssh_private_key_file=$ANSIBLE_KEY"
	fi

	ansible-playbook	-i $RHOST,\
						-e $ansibleoptions \
						$basedir/playbooks/$target.yml 
}

function readAnsibleConfigCache()
{
	export $(grep -f $ansibleconfigtemplate $ansibleconfigcache)
}

function writeAnsibleConfigcache()
{
	typeset | grep -f $ansibleconfigtemplate > $ansibleconfigcache
}

function readConfigcache()
{
	export $(grep -f $configtemplate $configcache)
}

function writeConfigcache()
{
	typeset | grep -f $configtemplate > $configcache
}

function getUserInfo()
{
	if [ "$ACTION" = "bootstrap" ]; then
		logp info "Your attention is required. The experiment requires you to answer truely and wholeheartedly."
		logp question "remote host's network address"; read -r RHOST
		logp question "remote host's port"; read -r RPORT
		logp question "remote host's first login user"; read -r DEFAULT_USER
		logp question "remote host's first login  pass"; read -r DEFAULT_PASS
		logp question "remote host's preferred admin user"; read -r ADMIN_USER
		logp question "remote host's preferred admin key"; read -r ADMIN_KEY
	fi

	writeConfigcache
}

function readUsers()
{
	if [ ! $# -eq 1 ] || [ ! -f $1 ]; then; logp fatal "Can't read users from non-existing file '$1'"; fi
	export ADMIN_USER=admin
	export ADMIN_GROUP=$(cat $1 | grep admin | head -n1 | cut -d: -f 2)
	export ADMIN_SSHKEY=$(cat $1 | grep admin | head -n1 | cut -d: -f 3)
}

#http://stackoverflow.com/a/18443300/441757
function realpath() {
  OURPWD=$PWD
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$OURPWD"
  echo "$REALPATH"
}

function prepareDependency()
{
	dep=$1
	if ! command -v $dep &> /dev/null; then
		logp info "Dependency '$dep' is missing. Attempting to install:"
		PKG_UPDATE || logp fatal "Couldn't update packages"
		PKG_INSTALL $dep || logp fatal "Couldn't install dependency '$dep'!"
	fi
}

function prepareEnvironment()
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
}

#https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
function pullMaster()
{
	logp info "Checking for update.."
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
	else
		logp warning "An update has failed you. Your computer will explode now."
	fi

}

function main()
{
	checkEnvironment
	handleFlags $@
	performActions $@
}

source $basedir/config.txt || exit 1
source $lib/checks.sh || exit 1
if [ checkConnectivity ]; then
		checkMasterUpdate && pullMaster
fi
main $@
