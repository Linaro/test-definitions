#!/bin/sh -e

soc_name="imx8mq"
bootloader_name="u-boot-${soc_name}.imx"
usage() {
    echo "Usage: $0 [-r <recovery file>] [-s <android_serial>]" 1>&2
    exit 1
}

while getopts ":s:r:" opt; do
  case "$opt" in
    s) ANDROID_SERIAL="${OPTARG}" ;;
    r) RECOVERY="${OPTARG}" ;;
    *) usage ;;
  esac
done

command(){
    if [ -n "$(which lava-test-case || true)" ]; then
        echo "$2"
        ($2 && lava-test-case "$1" --result pass) || (lava-test-raise "$1")
    else
        echo "$2"
        $2
    fi
}

echo "ANDROID_SERIAL" "${ANDROID_SERIAL}"
command 'LAVA_Check' true

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

initialize_adb

info_msg "About to update bootloader of device ${ANDROID_SERIAL}"

if [ -n "${RECOVERY}" ]; then
        command 'push-bootloader-file' "adb push ${RECOVERY} /data"
        echo "Get node"
	node_part1="$(adb shell "cat /proc/partitions" | grep -w mmcblk1 | awk '{print $1,$2}' | awk 'NR=1{print $1; exit}')"
	node_part2="$(adb shell "cat /proc/partitions" | grep -w mmcblk1 | awk '{print $1,$2}' | awk 'NR=1{print $2; exit}')"
        if [ -n "${node_part1}" ] && [ -n "${node_part2}" ]; then
	        command 'patch-bootloader' "adb shell mknod /dev/boot b ${node_part1} ${node_part2}"
	        command 'dd-bootloader' "adb shell dd if=/data/\"${bootloader_name}\" of=/dev/boot bs=1k seek=33; sync"
	        command 'adb-reboot' "adb reboot"
        fi
fi
