#!/bin/zsh

function firmware_prepare_network()
{
	[ ! -z "$WIFI_SSID" ] || logp fatal "Crash: Wifi name '$WIFI_SSID' not set!"
	[ ! -z "$WIFI_PASS" ] || logp fatal "Crash: Wifi password '$WIFI_PASS' not set!"

	[ ! -z ${blk_dev+x} ] && { [ -b "${blk_dev}1" ] && blk_dev_boot="${blk_dev}1" } || { [ -b "${blk_dev}p1" ] && blk_dev_boot="${blk_dev}p1" } || logp fatal "Couldn't find mountable bootpartition for ${blk_dev}"
	[ -d $os_mnt ] || mkdir -p $os_mnt || logp fatal "Couldn't setup mount directory @ $os_mnt"

	sudo mount "${blk_dev_boot}" $os_mnt || logp fatal "Failed to mount boot partion @ $os_mnt"

	[ -f $os_mnt/$OS_BOOT_NETWORK_CONFIG ] || logp fatal "Couldn't find network config file @ $os_mnt/$OS_BOOT_NETWORK_CONFIG"
	[ -z "$(cat $os_mnt/$OS_BOOT_NETWORK_CONFIG | grep -C5 $WIFI_PASS | grep $WIFI_SSID)" ] || { logp info "Wifi is already set!" && sudo umount $os_mnt && return 0 || return 1 }

	case $OS_DISTRO in
		ubuntu)
			p=$(pwd)
			cd $os_mnt
			logp info "Inserting network configuration..."
			sudo sh -c "cat >> $OS_BOOT_NETWORK_CONFIG \
			<<-EOF
			# inserted by bootstrapper arrrgh
			wifis:
			  wlan0:
			    dhcp4: true
			    optional: true
			    access-points:
			      $WIFI_SSID:
			        password: "$WIFI_PASS"
			EOF" || return 1
			cd $p
			sync
		;;
		*)
			logp warning "I don't  have a suitable wifi setup for your chosen distro $OS_DISTRO"
			sudo umount $os_mnt || logp fatal "Failed to umount boot partion @ $os_mnt"
			return 1
		;;
	esac
	sudo umount $os_mnt || logp fatal "Failed to umount boot partion @ $os_mnt"
}

function firmware_prepare_bootloader()
{
	[ ! -z ${blk_dev+x} ] && { [ -b "${blk_dev}1" ] && blk_dev_boot="${blk_dev}1" } || { [ -b "${blk_dev}p1" ] && blk_dev_boot="${blk_dev}p1" } || logp fatal "Couldn't find mountable bootpartition for ${blk_dev}"
	[ -d $os_mnt ] || mkdir -p $os_mnt || logp fatal "Couldn't setup mount directory @ $os_mnt"

	sudo mount "${blk_dev_boot}" $os_mnt || logp fatal "Failed to mount boot partion @ $os_mnt"

	case $OS_DISTRO in
		ubuntu)
			p=$(pwd)
			cd $os_mnt
				logp info "Inserting 'first run' requirements into firmware config."
				sudo sed -ri'' 's/^(\s*)(expire\s*:\s*true\s*$)/\1expire: false/' user-data # let Ansible handle that
				sudo sed -i'' '/package_update: true/c\package_update: false' user-data
				sudo sed -i'' '/package_upgrade: true/c\package_upgrade: false' user-data
			cd $p
			sync
		;;
		*)
			logp warning "I don't  have suitable bootloader setting for your chosen distro $OS_DISTRO"
			sudo umount $os_mnt || logp fatal "Failed to umount boot partion @ $os_mnt"
			return 1
		;;
	esac
	sudo umount $os_mnt || logp fatal "Failed to umount boot partion @ $os_mnt"
}
