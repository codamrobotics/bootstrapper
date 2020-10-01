#!/bin/zsh
#
# Configurations go into config.txt
#

basedir=$(dirname "$0")

function clean_up()
{
	case $1 in
		INT)
			logp fatal "aborting.."
		;;
		EXIT)
			# delete tmp files here
			logp endsection
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

function banner()
{
	clear
	source /etc/os-release
	IP="$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' |head -n1)"
	printf "\e[1m\e[33m+-------------------------------------------------------------------------------------------+\n"
	printf "|\e[0m`tput bold` %-89s `tput sgr0`\e[1m\e[33m|\n" "$PROJECT -- $PRETTY_NAME -- ROS:$ROS_RELEASE"
	printf "\e[1m\e[33m| \e[0m%-89s\e[1m\e[33m |\n" "`date`"
	#printf "\e[1m\e[33m| %-89s\e[1m\e[33m |\n" ""
	printf "|\e[0m`tput bold` %-89s `tput sgr0`\e[1m\e[33m|\n" "$(whoami)@$HOSTNAME ($IP)"
	printf "\e[1m\e[33m+-------------------------------------------------------------------------------------------+\n"
	logp beginsection	
}

function usage()
{
	echo USAGE
	exit 1
}

function handleFlags()
{
	if [ $# -eq 0 ]; then usage; fi

	# read action options
	for ARG in $@; do
		if [ "${ARG}" = "install" ]; then ACTION="${ARG}"; break; fi
		if [ "${ARG}" = "clean" ]; then ACTION="${ARG}"; break; fi
	done
	if [ "$ACTION" = "" ]; then
			logp fatal "No run command specified! (run $0 -h for usage)"
	fi
}

function performActions()
{
	case $ACTION in
		install)
			ansible-playbook $basedir/playbooks/system.yml || logp fatal "Failed to apply system rules!"
		;;
		clean)
		;;
	esac
}

#https://stackoverflow.com/a/932187/12394351
function checkConnectivity()
{
	def_gateway=$(ip r | grep default | cut -d ' ' -f 3)
	ping -q -w 1 -c 1 $def_gateway > /dev/null && return 0 || return 1
}

function checkEnvironment()
{
	source /etc/os-release
	if [ "$ID" != "$OS_DISTRO" ] || [ "$VERSION_CODENAME" != "$OS_RELEASE" ]; then
		logp fatal "This doesn't seem to be a target system : $PRETTY_NAME"
	fi
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
				apt update || logp fatal "Couldn't update packages"
				U=1
			fi
			apt -y install $dep || logp fatal "Couldn't install dependency '$dep'!"
		fi
	done
}

function main()
{
	banner
	checkEnvironment
	handleFlags $@
	prepareEnvironment
	performActions $@
}

source $basedir/config.txt || exit 1
main $@
