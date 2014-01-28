#!/bin/bash
#
# WiFi test cases for Linaro ubuntu
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
# Author: Botao Sun <botao.sun@linaro.org>

source include/sh-test-lib

## Test case definitions
# Check if wifi interface exists or not
test_has_interface() {
    TEST="has_interface"

    echo "###########################################"
    ifconfig -a
    echo "###########################################"

    wifi_interface=`ifconfig -a | grep wlan0`
    echo "The WiFi Interface Name is $wifi_interface"

    if [ -z "$wifi_interface" ]; then
        fail_test "The WiFi interface doesn't exist, WiFi enable failed"
        return 1
    fi

    pass_test
}

# Check if the wireless access point can be connected or not
test_connect_to_ap() {
    TEST="connect_to_ap"

    network_config_file="/etc/network/interfaces"
    echo $network_config_file

    # Turn off Ethernet
    mv $network_config_file $network_config_file".bak"
    echo -ne "auto wlan0\niface wlan0 inet dhcp\nwpa-ssid $1\nwpa-psk $2" > $network_config_file

    service networking restart

    echo "###########################################"
    ifconfig wlan0
    echo "###########################################"

    # Get ip address from WiFi interface
    ip_address_line=`ifconfig wlan0 | grep "inet addr"`
    echo $ip_address_line

    ip_address_array=($ip_address_line)
    ip_address_element=${ip_address_array[1]}
    echo $ip_address_element

    ip_address=${ip_address_element:5}
    echo $ip_address

    # Ping test here
    ping -c 5 -I ${ip_address} www.google.com
    if [ $? -ne 0 ]; then
        fail_test "Ping test failed from $ip_address"
        return 1
    fi

    # Packet loss report
    packet_loss_line=`ping -c 5 -I ${ip_address} www.google.com | grep "packet loss"`
    echo $packet_loss_line

    packet_loss_array=($packet_loss_line)
    packet_loss=${packet_loss_array[5]}
    echo "The packet loss rate is $packet_loss"

    if [ "$packet_loss" != "0%" ]; then
        fail_test "Packet loss happened, rate is $packet_loss"
        return 1
    fi

    # Restore the environment
    rm -rf $network_config_file
    mv $network_config_file".bak" $network_config_file

    service networking restart
    sleep 30

    pass_test
}

# run the tests
test_has_interface
test_connect_to_ap $1 $2
# clean exit so lava-test can trust the results
exit 0