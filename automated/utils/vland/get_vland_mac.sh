#!/bin/sh

set -e

vland_name="${1}"

iface=$("$(readlink -f "$(dirname "$0")")"/get_vland_interface.sh "${vland_name}")
if [ -z "${iface}" ]; then
    exit 1
fi
cat /sys/class/net/"${iface}"/address
