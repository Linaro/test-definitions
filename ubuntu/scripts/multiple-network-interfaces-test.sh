#!/bin/sh
#
# Multiple network interfaces test for ubuntu
#
# Copyright (C) 2013, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>

# Print network gateway
GATEWAY=$1
echo "GATEWAY: $GATEWAY"

# Print all network interfaces
ifconfig -a

# Pass rp_filter=0 to kernel to address ARP flux
echo "Pass rp_filter=0 to kernel to address ARP flux"
for i in all default; do
    echo 0 > /proc/sys/net/ipv4/conf/$i/rp_filter
    sysctl -a |grep $i.rp_filter
done
if [ $? -eq 0 ]; then
    lava-test-case address-arp-flux --result pass
else
    lava-test-case address-arp-flux --result fail
    exit 1
fi

# Set dhclient timeout to 2 minutes.
cp /etc/dhcp/dhclient.conf /etc/dhcp/dhclient.conf.original
echo "timeout 120;" >> /etc/dhcp/dhclient.conf

for INTERFACE in `ifconfig -a |grep eth |awk '{print $1}'`; do
    # Check IP address on each interface. If IP is empty, use dhclient request
    # IP from dhcp server, then check if IP address is empty again.
    IP=$(ifconfig $INTERFACE | grep "inet addr" | awk '{print substr($2,6)}')
    if [ -z $IP ]; then
        dhclient $INTERFACE
        if [ $? -eq 0 ]; then
            IP=$(ifconfig $INTERFACE | grep "inet addr" \
                | awk '{print substr($2,6)}')
            if [ -z $IP ]; then
                lava-test-case $INTERFACE-obtain-ip-address --result fail
                lava-test-case $INTERFACE-ping-test --result skip
                continue
            else
                echo "$INTERFACE IP address: $IP"
                lava-test-case $INTERFACE-obtain-ip-address --result pass
            fi
        else
            lava-test-case $INTERFACE-obtain-ip-address --result fail
            lava-test-case $INTERFACE-ping-test --result skip
            continue
        fi
    else
        echo "$INTERFACE IP address: $IP"
        lava-test-case $INTERFACE-obtain-ip-address --result pass
    fi

    # Run ping test on the specific interface
    ping -c 5 -I $INTERFACE $GATEWAY
    if [ $? -eq 0 ]; then
        lava-test-case $INTERFACE-ping-test --result pass
    else
        lava-test-case $INTERFACE-ping-test --result fail
    fi
done

# Restore dhclient setting.
mv /etc/dhcp/dhclient.conf.original /etc/dhcp/dhclient.conf
