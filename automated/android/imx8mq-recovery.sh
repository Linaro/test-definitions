#!/bin/bash

set -e

while getopts ":r:x" opt; do
  case $opt in
    x)
      # test mode
      EXIT="true"
      ;;
    r)
      # recovery.bin
      RECOVERY=${OPTARG}
      ;;
    ?)
      echo "Usage:"
      echo "-r - recovery image, e.g. recovery.bin"
      echo "-x - print options and exit"
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

command(){
    if [ -n "$(which lava-test-case || true)" ]; then
        echo $2
        $2 && lava-test-case "$1" --result pass || lava-test-raise "$1"
    else
        echo $2
        $2
    fi
}

echo "RECOVERY" ${RECOVERY}
command 'LAVA_Check' true

if [ -n "${EXIT}" ]; then
  echo "Exiting as requested"
  exit
fi

devices=$(adb devices | grep -w device)
if [ -n "${devices}" ]; then
	if [ -n "${RECOVERY}" ]; then
		echo "Push bootloader file"
		command 'push-bootloader-file' "adb -d push ${RECOVERY} /data"
	fi
	echo "Get node"
	node=$(adb -d shell "cat /proc/partitions" | grep -w mmcblk1 | awk '{print $1,$2}')
	if [ -n "${node}" ]; then
    		echo "Patch bootloader"
		command 'patch-bootloader' "adb -d shell "mknod /dev/boot b ${node}""
	fi
	if [ -n "${RECOVERY}" ]; then
		echo "Push bootloader file"
		command 'dd-bootloader' "adb -d shell "dd if=/data/${RECOVERY} of=/dev/boot bs=1k seek=33; sync""
	fi
    	echo "Adb reboot"
    	command 'adb-reboot' "adb -d reboot"
fi

