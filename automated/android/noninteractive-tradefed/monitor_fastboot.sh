#!/bin/sh -x
while true;
do
    date
    # fastboot continue # still not supported for all platforms, like db845c, x15
    # so continue using fastboot boot command here
    echo "Run fastboot boot to wait and reboot the device again"
    f_lxc_boot=$(find /lava-lxc -type f -name "*boot*.img")
    f_docker_boot=$(find /lava-downloads -type f -name "*boot*.img")
    if [ -n "${f_lxc_boot}" ] && [ -f "${f_lxc_boot}" ]; then
        # for lxc container method
        fastboot boot "${f_lxc_boot}"
    elif [ -n "${f_docker_boot}" ] && [ -f "${f_docker_boot}" ]; then
        # for docker method
        fastboot boot "${f_docker_boot}"
    else
        echo "No boot image found under /lava-lxc and /lava-downloads, please check and try again!"
        exit 1
    fi
    sleep 30
done
