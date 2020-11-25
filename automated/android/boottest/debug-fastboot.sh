#!/bin/bash

id
echo "----fastboot devices list from /sys/bus/usb/devices start----"
ls /sys/bus/usb/devices/*/serial | while read -r device; do
    basedir=$(dirname ${device})
    basedir_name=$(basename ${basedir})
    #interface_dir="/sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.*"
    ls -1d /sys/bus/usb/devices/${basedir_name}/${basedir_name}:1.* 2>/dev/null| while read -r interface; do
        bInterfaceClass=$(cat ${interface}/bInterfaceClass)
        bInterfaceSubClass=$(cat ${interface}/bInterfaceSubClass)
        bInterfaceProtocol=$(cat ${interface}/bInterfaceProtocol)
        if [ "X${bInterfaceClass}" = "Xff" ] && \
            [ "X${bInterfaceSubClass}" = "X42" ] && \
            [ "X${bInterfaceProtocol}" = "X03" ]; then
            serial=$(cat ${device})
            if [ ! -f ${interface}/interface ]; then
                echo "${serial} no-interface-fastboot ${device}"
            else
                echo "${serial} interface-$(cat ${interface}/interface) ${device}"
            fi
        fi
    done
done
echo "----fastboot devices list from /sys/bus/usb/devices end----"
echo "----fastboot devices list from fastboot devices command start----"
fastboot devices
echo "----fastboot devices list from fastboot devices command end----"
