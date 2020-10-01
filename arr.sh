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
		OS_UPDATE="brew update"
		;;
	Linux)
		flavour=$(cat /etc/os-release | grep ID_LIKE | cut -d= -f2)
		case $flavour in
			arch)
				OS_UPDATE="sudo pacman -Sy"
				;;
			ubuntu)
				OS_UPDATE="apt-get update"
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
			zsh -c "echo -e \"\e[1m\e[33m*********************************************************************************************\""
			zsh -c "echo -e \"\e[1m\e[33m|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\e[0m\""
			;;
		endsection)
			zsh -c "echo -e \"\e[1m\e[33m|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\""
			zsh -c "echo -e \"\e[1m\e[33m*********************************************************************************************\e[0m\""
			;;
	esac
}

function tmp_create()
{
	if [ -d $src_cpy ]; then logp fatal "Temporary directory $src_cpy already exists!"; fi
	cp -r $src $src_cpy || logp fatal "Couldn't setup tmp directory!"
}

function tmp_delete()
{
	if [ -d $src_cpy ]; then
		rm -r $src_cpy
	fi
}

function banner()
{
	banner=true
	clear
	source /etc/os-release
	IP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' |head -n1)"
	printf "\e[1m\e[33m+-------------------------------------------------------------------------------------------+\n"
	printf "|\e[0m`tput bold` %-89s `tput sgr0`\e[1m\e[33m|\n" "$PROJECT -- $PRETTY_NAME -- ROS:$ROS_RELEASE"
	printf "\e[1m\e[33m| \e[0m%-89s\e[1m\e[33m |\n" "`date`"
	#printf "\e[1m\e[33m| %-89s\e[1m\e[33m |\n" ""
	printf "|\e[0m`tput bold` %-89s `tput sgr0`\e[1m\e[33m|\n" "$(whoami)@$HOST ($IP)"
	printf "\e[1m\e[33m+-------------------------------------------------------------------------------------------+\n"
	logp beginsection	
}

function usage()
{
	echo "Usage:"
cat<<EOF
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

					checkIsReachable $RHOST || logp fatal "Host '$RHOST' is not reachable at this time (ping test)."
					banner
					ansible-playbook -i $RHOST, $basedir/playbooks/system.yml || logp fatal "Failed to apply system rules!"
					ansible-playbook -i $RHOST, $basedir/playbooks/ros.yml || logp fatal "Failed to apply ros rules!"
				;;
				arduino-env)
					if [ ! $# -eq 3 ]; then logp usage "$callee bootstrap arduino-env [[HOST:DIRECTORY] | [DIRECTORY]]"; fi
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

function checkIsIP()
{
	[[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

function checkIsReachable()
{
	ping -q -w 1 -c 1 $1 > /dev/null $2 > /dev/null
}

#https://stackoverflow.com/a/932187/12394351
function checkConnectivity()
{
	def_gateway=$(ip r | grep default | cut -d ' ' -f 3)
	ping -q -w 1 -c 1 $def_gateway > /dev/null
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

function prepareEnvironment()
{
	U=0
	for dep in "${DEPENDENCIES[@]}"
	do
		if ! command -v $dep &> /dev/null; then
			if [ $U -eq 0 ]; then
				$PAC_UPDATE || logp fatal "Couldn't update packages"
				U=1
			fi
			$PAC_INSTALL $dep || logp fatal "Couldn't install dependency '$dep'!"
		fi
	done
}

function main()
{
	checkEnvironment
	handleFlags $@
	prepareEnvironment
	performActions $@
}

source $basedir/config.txt || exit 1
main $@
