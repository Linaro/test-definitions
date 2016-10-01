#!/bin/sh

set -e

rootdir=$(readlink -f $(dirname $0))

vland_name=${1}

iface=$(${rootdir}/get_vland_interface.sh ${vland_name})
if [ -z "${iface}" ]; then
    exit 1
fi
mac=$(cat /sys/class/net/${iface}/address)

echo ${mac}
