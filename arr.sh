#!/bin/zsh
#
# Configurations go into config.txt
#

# environment variables
kernel="$(uname -s)"
callee=$0
basedir=$(dirname "$0")
src=$basedir/playbooks
src_cpy=$basedir/.src_cpy
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
	if [ -d $src_cpy ]; then logp fatal "Temporary directory $src_cpy already exists!"; fi
	cp -r $src $src_cpy || logp fatal "Couldn't setup tmp directory!"
}

function tmp_delete()
{
	if [ -f $basedir/.tmp ]; then rm -f $basedir/.tmp; fi
	if [ -d $src_cpy ]; then rm -r $src_cpy; fi
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
	ip="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' |head -n1)"
	zsh -c "echo -e \"\e[1m\e[33m+$(termFill '-' $((cols - 2)))+\""
	printf "|\e[0m`tput bold` %-$((cols - 4))s `tput sgr0`\e[1m\e[33m|\n" "$callee -- ROS:$ROS_RELEASE -- running on $PRETTY_NAME"
	printf "|\e[0m`tput bold` %-$((cols - 4))s `tput sgr0`\e[1m\e[33m|\n" "$(whoami)@$HOST ($ip)"
	#printf "\e[1m\e[33m| \e[0m%-$((cols - 4))s\e[1m\e[33m |\n" "`date`"
	printf "\e[1m\e[33m| %-$((cols - 4))s\e[1m\e[33m |\n" ""
	if [ $# -gt 0 ]; then; printf "\e[1m\e[33m| %-$((cols - $((4 + ${#date})) ))s%-5s\e[1m\e[33m |\n" "$1" "`date`"; fi
	logp beginsection	
}

function usage()
{
	(logp usage "")
	cat<<-EOF
		$callee bootstrap raspberry [RHOST]
		$callee bootstrap arduino-env [[HOST:DIRECTORY] | [DIRECTORY]]
		$callee help	
		$callee clean
	EOF
	exit 1
}

function handleFlags()
{
	if [ $# -eq 0 ]; then usage; fi

	# read action options
	for ARG in $@; do
		if [ "${ARG}" = "bootstrap" ]; then ACTION="${ARG}"; break; fi
		if [ "${ARG}" = "clean" ]; then ACTION="${ARG}"; break; fi
		if [ "${ARG}" = "help" ]; then ACTION="${ARG}"; break; fi
	done
	if [ "$ACTION" = "" ]; then
			usage
	fi
}

function performActions()
{
	case $ACTION in
		bootstrap)
			if [ $# -lt 2 ]; then logp usage "$callee bootstrap [raspberry | arduino-env ] [ARGS]"; fi
			case $2 in
				raspberry)
					if [ ! $# -eq 3 ]; then logp usage "$callee bootstrap raspberry [RHOST]"; fi
					export RHOST=$3

					banner "bootstrapping raspberry at $RHOST"
					getUserInfo	|| logp fatal "Failed to get user info"
					checkIsReachable $RHOST || logp fatal "Host '$RHOST' is not reachable at this time (ping test)."
					checkIsManageable $RHOST $RPORT $RUSER $RPASS || logp fatal "Couldn't login to $RHOST with given credentials."
					prepareEnvironment || logp fatal "Couldn't prepare environment"
					#readUsers $basedir/userlist.txt|| logp fatal "Couldn't read users"
					ansible-playbook -i $RHOST, -e  "ansible_port=$RPORT ansible_ssh_user=$RUSER ansible_ssh_pass=$RPASS"  $basedir/playbooks/system.yml || logp fatal "Failed to apply system rules!"
					ansible-playbook -i $RHOST, $basedir/playbooks/ros.yml || logp fatal "Failed to apply ros rules!"
				;;
				arduino-env)
					if [ ! $# -eq 3 ]; then logp usage "$callee bootstrap arduino-env [[HOST:DIRECTORY] | [DIRECTORY]]"; fi
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
		;;
		help)
			usage
		;;
	esac
}

function getUserInfo()
{
	if [ "$ACTION" = "bootstrap" ]; then
		logp info "The following info is required. The experiment requires you to answer truely and wholeheartedly."
		logp question "remote host's network address"; read -r RHOST
		logp question "remote host's port"; read -r RPORT
		logp question "remote host's ssh user"; read -r RUSER
		logp question "remote host's ssh pass"; read -r RPASS
	fi
}

function readUsers()
{
	if [ ! $# -eq 1 ] || [ ! -f $1 ]; then; logp fatal "Can't read users from non-existing file '$1'"; fi
	export ADMIN_USER=admin
	export ADMIN_GROUP=$(cat $1 | grep admin | head -n1 | cut -d: -f 2)
	export ADMIN_SSHKEY=$(cat $1 | grep admin | head -n1 | cut -d: -f 3)
}

function lock_access()
{
	if ssh -p $RPORT -q $RUSER@$RHOST exit; then
		ssh -p $RPORT $RUSER@$RHOST 'bash -s' <<-EOF
			useradd -m $ADMIN_USER
			
		EOF

	fi
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

function checkIsIP()
{
	[[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

function checkIsReachable()
{
	case $kernel in
		Darwin)
			ping -q -t 1 -c 1 $1 >/dev/null 2>&1
		;;
		Linux)
			ping -q -w 1 -c 1 $1 >/dev/null 2>&1
		;;
	esac
}

function checkIsManageable()
{
	prepareDependency sshpass
	echo "$4" | sshpass ssh -p $2 -o PreferredAuthentications=password -o PubkeyAuthentication=no $3@$1 exit 1>/dev/null
}

#https://stackoverflow.com/a/932187/12394351
function checkConnectivity()
{
	case $kernel in
		Darwin)
			def_gateway=$(route get default | grep gateway | cut -d: -f2| sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
			ping -q -t 1 -c 1 $def_gateway > /dev/null
		;;
		Linux)
			def_gateway=$(ip r | grep default | cut -d ' ' -f 3)
			ping -q -w 1 -c 1 $def_gateway > /dev/null
		;;
	esac
}

function checkEnvironment()
{
	#source /etc/os-release
	#if [ "$ID" != "$OS_DISTRO" ] || [ "$VERSION_CODENAME" != "$OS_RELEASE" ]; then
	#	logp fatal "This doesn't seem to be a target system : $PRETTY_NAME"
	#fi
	if ! checkConnectivity; then
		logp fatal "Couldn't connect to network!"
	fi
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

function main()
{
	checkEnvironment
	handleFlags $@
	performActions $@
}

source $basedir/config.txt || exit 1
main $@
