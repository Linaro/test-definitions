#!/bin/sh

set -e

vland_name=${1}

iface=$("$(readlink -f "$(dirname "$0")")"/get_vland_interface.sh "${vland_name}")
if [ -L "/sys/class/net/${iface}/device" ]; then
	basename "$(readlink -f "/sys/class/net/${iface}/device")"
else
	exit 1
fi
