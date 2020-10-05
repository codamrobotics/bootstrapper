export XZ_DEFAULTS="-T0"

function image_attain()
{
	[ -d $downloads ] || mkdir -p $downloads || logp fatal "Couldn't create downloads folder."
	if [ ! -f $os_img ]; then
		prepareDependency wget
		logp info "Acquiring os image : $OS_IMG_LINK"
		wget -q --show-progress -O $os_img $OS_IMG_LINK || logp fatal "Failed to acquire image from $OS_IMG_LINK. Is the link ok?"
		return $?
	else
		return 1
	fi
}

function image_checksum_attain()
{
	[ -d $downloads ] || mkdir -p $downloads || logp fatal "Couldn't create downloads folder."
	if [ ! -f $os_img_checksum ]; then
		prepareDependency wget
		logp info "acquiring os image checksums : $OS_IMG_CHECKSUM_LINK"
		wget -q --show-progress -O $os_img_checksum $OS_IMG_CHECKSUM_LINK || logp fatal "Couldn't acquire checksum file. Is the link ok?"
		grep $OS_IMG $os_img_checksum > $os_img_checksum.tmp && mv $os_img_checksum.tmp $os_img_checksum || logp fatal "Faileded extracting checksums."
		return $?
	fi
}

function blk_dev_fill_zeros()
{
	[ -b $1 ] || logp fatal "'$1' is not a block device!"
	logp info "Zero'ing out block device $1! (grab a coffee and a smoke)"
	sudo dd if=/dev/zero of=$1 bs=4M count=1250 status=progress && logp info "Syncing last zeros to disk..." && sync || { logp warning "dd is probably bitching about running out of space. No problem." && true }
}

function image_verify()
{
	[ -d $downloads ] || mkdir -p $downloads || logp fatal "Couldn't create downloads folder."
	if [ -f $os_img ]; then
		image_checksum_attain
		prepareDependency sha256sum
		if ! ( cd $downloads && logp info_nnl "Verifiying image : " && sha256sum -c $os_img_checksum ); then
			logp warning "Incomplete/corrupt image found (checksum) : $os_img, removing..."
			rm -f $os_img || logp fatal "Couldn't remove image : $os_img"
		else
			logp info "Image has been found and is in good health."
			return 0
		fi
	else
		return 1
	fi

}

function image_prepare()
{
	[ -d $downloads ] || mkdir -p $downloads || logp fatal "Couldn't create downloads folder."
	if [ -f $os_img ]; then
		image_verify || { image_attain && image_verify }|| logp fatal "Bloody image is not cooperating.."
	else
		{ image_attain && image_verify }  || logp fatal "Bloody image is not cooperating.."
	fi
}

function blk_verify_is_not_mounted() { [ -z "$(mount | grep $1)" ] }

function image_write()
{
	# todo: handle plurality of compressors

	[ -b $blk_dev ] || logp fatal "'$blk_dev' is not a block device!"
	[ -f $os_img ] || logp fatal "'$os_img' does not exist!"

	blk_verify_is_not_mounted $blk_dev || logp fatal "Are you crazy? Block device $blk_dev is mounted!"

	logp question "About to start zero'ing & writing $OS_IMG on $blk_dev : How sure are you of this? (Y/N)"; read -r response
	if ! { [ "$response" = "y" ] || [ "$response" = "Y" ] }; then  logp fatal "A decision of no consequence."; fi

	blk_dev_fill_zeros $blk_dev || logp fatal "Failed filling '$blk_dev' with zeros!"

	if [ ! -z "${OS_IMG_COMP_EXT+x}" ]; then
		prepareDependency xz
		logp info "Injecting $blk_dev with image '$OS_IMG' ..."
		xz -T0 -dk < $os_img - | sudo dd of=$blk_dev bs=4M status=progress && logp info "Download complete. Syncing..." && sync || logp fatal "Failed writing $os_img to $blk_dev"
	else
		sudo dd if=$os_img of=$blk_dev bs=4M status=progress && logp info "Download complete. Syncing..." && sync || logp fatal "Failed writing $os_img to $blk_dev"
	fi
}
#!/bin/zsh

function image_prepare_network()
{
	[ -z ${blk_dev+x} ] || [ -b "${blk_dev}1" ] || logp fatal "Couldn't find mountable partition @ ${blk_dev}1"
	[ -d $os_mnt ] || mkdir -p $os_mnt || logp fatal "Couldn't setup mount directory @ $os_mnt"

	sudo mount "${blk_dev}1" $os_mnt || logp fatal "Failed to mount boot partion @ $os_mnt"

	[ ! -z "$WIFI_SSID" ] || logp fatal "Wifi name '$WIFI_SSID' not set!"
	[ ! -z "$WIFI_PASS" ] || logp fatal "Wifi password '$WIFI_PASS' not set!"

	[ -f $os_mnt/$OS_BOOT_NETWORK_CONFIG ] || logp fatal "Couldn't find network config file @ $os_mnt/$OS_BOOT_NETWORK_CONFIG"
	[ -z "$(cat $os_mnt/$OS_BOOT_NETWORK_CONFIG | grep -C5 $WIFI_PASS | grep $WIFI_SSID)" ] || { logp info "Wifi is already set!" && return 0 }

	case $OS_DISTRO in
		ubuntu)
			p=$(pwd)
			cd $os_mnt
			logp info "Inserting network configuration..."
			sudo sh -c "cat -e >> $OS_BOOT_NETWORK_CONFIG \
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
