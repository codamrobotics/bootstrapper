#!/bin/zsh

{{ which md5 && MD5=md5  } || { which md5sum && MD5=md5sum }} &>/dev/null
{{ which sha256 && SHA256=sha256  } || { which sha256sum && SHA256=sha256sum }} &>/dev/null
{{ which sha512 && SHA512=sha512  } || { which sha512sum && SHA512=sha512sum }} &>/dev/null

function logp()
{ 
	case "$1" in
		info) zsh -c "echo -e \"\e[32m\e[1m* \e[0m$2\"" ;;
		info_nnl) zsh -c "echo -n -e \"\e[32m\e[1m* \e[0m$2\"" ;;
		usage) zsh -c "echo -e \"\e[32m\e[1mUsage: \e[0m$2\""; exit 0 ;;
		question) zsh -c "echo -e -n \"\e[32m\e[1mUse your keyboard:  \e[0m$2 : \"" ;;
		warning) zsh -c "echo -e \"\033[31m\e[1m* \e[0m$2\"" ;;
		warning_nnl) zsh -c "echo -n -e \"\033[31m\e[1m* \e[0m$2\"" ;;
		fatal) zsh -c "echo -e \"\e[31m\e[1m* \e[0m\e[30m\e[101m$2\e[0m\""; exit 1 ;;
		beginsection)
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '*')\e[0m\""
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '|')\e[0m\"" ;;
		endsection)
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '|')\e[0m\""
				zsh -c "echo -e \"\e[1m\e[33m$(termFill '*')\e[0m\"" ;;
	esac
}

function termFill() { 
		cols=$(tput cols)
		if [ $# -gt 1 ]; then while [[ $x -lt $cols ]] && [[ $x -lt $2 ]]; do printf "%s" "$1"; let x=$x+1; done;
		else while [[ $x -lt $cols ]]; do printf "%s" "$1"; let x=$((x+1)); done; fi
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
	[ "${REALPATH: -1}" = "." ] && [ ! ${#REALPATH} -eq 1 ] && REALPATH=$(echo $REALPATH | sed 's/.$//')
	[ "${REALPATH: -1}" = "/" ] && [ ! ${#REALPATH} -eq 1 ] && REALPATH=$(echo $REALPATH | sed 's/\/$//')
	cd "$OURPWD"
	echo "$REALPATH"
}
