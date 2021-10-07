#!/bin/zsh

function create_accesspoint_on_arch()
{
    logp info "Preparing dependencies..."
	prepareDependency create_ap || return 1

	[ ! -z "${WIFI_SSID}" ] && [ ! -z "${WIFI_PASS}" ] && [ ! -z "${WIFI_DEV}" ] && [ ! -z "${UPLINK_DEV}" ] || logp fatal "Accesspoint information not avaiable."
	logp info 'Creating accesspoint with the following data : '$WIFI_DEV' '$WIFI_SSID' '$WIFI_PASS'.'
	logp info "Kill with Ctrl+c"
	sudo create_ap "$WIFI_DEV" "$UPLINK_DEV" "$WIFI_SSID" "$WIFI_PASS"
}

function create_accesspoint_on_debian()
{
    logp info "Preparing dependencies..."
    prepareDependency git || return 1
    prepareDependency bash || return 1
    prepareDependency procps || return 1
    prepareDependency iproute2 || return 1
    prepareDependency dnsmasq || return 1
    prepareDependency iptables || return 1
    prepareDependency hostapd || return 1
    
    local lnxrouter_d=$downloads/lnxrouter
    local lnxrouter=$lnxrouter_d/lnxrouter
    [ -d $lnxrouter_d ] || git clone https://github.com/garywill/linux-router.git $lnxrouter_d || logp fatal "Failed to clone linux-router."
    [ -f $lnxrouter ] || logp fatal "Couldn't find lnxrouter at '$lnxrouter/lnxrouter'."

	[ ! -z "${WIFI_SSID}" ] && [ ! -z "${WIFI_PASS}" ] && [ ! -z "${WIFI_DEV}" ] && [ ! -z "${UPLINK_DEV}" ] || logp fatal "Accesspoint information not avaiable."
	logp info 'Creating accesspoint with the following data : '$WIFI_DEV' '$WIFI_SSID' '$WIFI_PASS'.'
	logp info "Kill with Ctrl+c"
	sudo $lnxrouter --no-virt --ap "$WIFI_DEV" "$WIFI_SSID" -p "$WIFI_PASS"
}

function create_accesspoint()
{
    os_flavour=$(cat /etc/os-release | grep ID_LIKE | cut -d= -f2)
    case $os_flavour in
        arch)
            create_accesspoint_on_arch
            return ;
            ;;
        debian)
            create_accesspoint_on_debian
            return ;
            ;;
        *) logp usage "You have choosen an operating system that is not on good terms with the Federation." ;;
    esac
}
