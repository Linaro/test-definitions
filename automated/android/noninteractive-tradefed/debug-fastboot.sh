#!/bin/bash

# check the user that run this script
id
echo "----fastboot devices list from /sys/bus/usb/devices start----"
fastboot_devices=""
devpaths=""
#ls /sys/bus/usb/drivers/usb/*/serial | while read -r device; do
#ls /sys/bus/usb/devices/*/serial | while read -r device; do
find -L /sys/bus/usb/devices/ -maxdepth 2 -type f -name serial | while read -r device; do
    basedir=$(dirname "${device}")
    realpath_basedir=$(realpath "${basedir}")
    basedir_name=$(basename "${basedir}")
    #interface_dir="/sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.*"
    #ls -1d /sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.* 2>/dev/null| while read -r interface; do
    find -L "/sys/bus/usb/devices/${basedir_name}" -maxdepth 1 -mindepth 1  -type d -name "${basedir_name}:1.*" | while read -r interface; do
        bInterfaceClass=$(cat "${interface}/bInterfaceClass")
        bInterfaceSubClass=$(cat "${interface}/bInterfaceSubClass")
        bInterfaceProtocol=$(cat "${interface}/bInterfaceProtocol")
        if [ "X${bInterfaceClass}" = "Xff" ] && \
                [ "X${bInterfaceSubClass}" = "X42" ] && \
                [ "X${bInterfaceProtocol}" = "X03" ]; then

            devnum=$(cat "${interface}/devnum")
            busnum=$(cat "${interface}/busnum")
            serial=$(cat "${device}")
            if [ ! -f "${interface}/interface" ]; then
                echo "${serial} no-interface-fastboot ${device}"

                fastboot_devices="${fastboot_devices} ${realpath_basedir}"

                busnum=$(printf "%03d" "${busnum}")
                devnum=$(printf "%03d" "${devnum}")
                devpath="/dev/bus/usb/${busnum}/${devnum}"
                devpaths="${devpaths} ${devpath}"
            else
                echo "${serial} interface-$(cat "${interface}/interface") ${device}"
            fi
        fi
    done
done
echo "----fastboot devices list from /sys/bus/usb/devices end----"
echo "----fastboot devices list from fastboot devices command start----"
fastboot devices
echo "----fastboot devices list from fastboot devices command end----"
# check the owner and group of the android devices
echo "----list usb devices owner and group start----"
ls -l /dev/bus/usb/*/*
echo "----list usb devices owner and group end----"
