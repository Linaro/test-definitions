#!/bin/sh

set -e

DEVICE=$1

if [ -z "${DEVICE}" ]; then
	echo "Must specify the device which has been configured by the kernel."
	exit 1
fi

if [ -e '/etc/resolv.conf' ]; then
	echo "Not altering an existing /etc/resolv.conf"
	echo "If DNS does not operate for local addresses, see"
	echo "/run/net-*.conf"
	exit 2
fi

if [ ! -e "/run/net-${DEVICE}.conf" ]; then
	echo "/run/net-${DEVICE}.conf is missing - wrong interface specified?"
	exit 3
fi

# shellcheck source=eth0
. /run/net-"${DEVICE}".conf

echo domain "${DNSDOMAIN}" > /etc/resolv.conf
echo nameserver "${IPV4DNS0}" >> /etc/resolv.conf
