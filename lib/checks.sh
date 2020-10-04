#!/bin/zsh

function checkHasAnsibleKey() { [ -f $ANSIBLE_KEY ] }

function checkMasterUpdate() {
		if [ ! -f $refresh ] || [ "$(date +'%d')" != "$(cat $refresh)" ]; then; (date +'%d' > $refresh) && return 0; else; return 1; fi
}

function checkConfigcacheExists() { [ -f $configcache ] }

function checkIsIP() { [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] }

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
	if [ $# -eq 5 ]; then
		ssh -p $2 -i $5 -o PreferredAuthentications=publickey $3@$1 exit 1>/dev/null 2>&1
		return $?
	else
		prepareDependency sshpass
		echo "$4" | sshpass ssh -p $2 -o PreferredAuthentications=password -o PubkeyAuthentication=no $3@$1 exit 1>/dev/null 2>&1
		return $?
	fi
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
