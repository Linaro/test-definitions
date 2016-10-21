#!/bin/sh

set -e

rootdir=$(readlink -f $(dirname $0))

vland_name=${1}

iface=$(${rootdir}/get_vland_interface.sh ${vland_name})
if [ -L /sys/class/net/${iface}/device ]; then
	basename $(readlink -f /sys/class/net/${iface}/device)
else
	exit 1
fi
