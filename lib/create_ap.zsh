#!/bin/zsh

function create_accesspoint()
{
	prepareDependency create_ap || return 1

	[ ! -z "${WIFI_SSID}" ] && [ ! -z "${WIFI_PASS}" ] && [ ! -z "${WIFI_DEV}" ] || logp fatal "Accesspoint information not avaiable."
	logp info 'Creating accesspoint with the following data : '$WIFI_DEV' '$WIFI_SSID' '$WIFI_PASS'.'
	logp info "Kill with Ctrl+c"
	sudo create_ap "$WIFI_DEV" "$WIFI_DEV" "$WIFI_SSID" "$WIFI_PASS"
}
