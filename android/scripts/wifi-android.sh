#!/system/bin/sh
#
# WiFi test cases for Linaro Android
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

function check_return_fail() {
    if [ $? -ne 0 ]; then
        fail_test "$1"
        return 0
    else
        return 1
    fi
}

function fail_test() {
    local reason=$1
    echo "${TEST}: FAIL - ${reason}"
}

function pass_test() {
    echo "${TEST}: PASS"
}

## Test case definitions
# Check if wifi can be enabled or not
test_enable_wifi() {
    TEST="enable_wifi"

    echo `which svc`
    echo `which busybox`

    svc wifi enable

    if [ $? -ne 0 ]; then
        fail_test "Run svc WiFi enable command failed"
        return 1
    fi

    sleep 50

    echo "###########################################"
    busybox ifconfig -a
    echo "###########################################"

    wifi_interface=`busybox ifconfig -a | busybox grep wlan0`
    echo "The WiFi Interface Name is $wifi_interface"

    if [ -z "$wifi_interface" ]; then
        fail_test "The WiFi interface is empty, WiFi enable failed"
        return 1
    fi

    pass_test
}

# Check if wifi can be disabled or not
test_disable_wifi() {
    TEST="disable_wifi"

    echo `which svc`
    echo `which busybox`

    svc wifi disable

    if [ $? -ne 0 ]; then
        fail_test "Run svc WiFi disable command failed"
        return 1
    fi

    sleep 30

    echo "###########################################"
    busybox ifconfig -a
    echo "###########################################"

    wifi_interface=`busybox ifconfig -a | busybox grep wlan0`

    echo "After ran WiFi disable command, the WiFi interface name is $wifi_interface"

    if [ ! -z "$wifi_interface" ]; then
        fail_test "The WiFi interface remains, WiFi disable failed"
        return 1
    fi

    pass_test
}

# Check if the wireless access point can be connected or not
test_connect_to_ap() {
    TEST="connect_to_ap"

    # Turn off Ethernet
    busybox ifconfig eth0 down
    if [ $? -ne 0 ]; then
        fail_test "Ethernet turn off failed"
        return 1
    fi

    svc wifi enable
    if [ $? -ne 0 ]; then
        fail_test "Run svc WiFi enable command failed"
        return 1
    fi

    sleep 30

    echo `which wpa_cli`

    # Connect to wireless access point
    wpa_cli list_networks
    wpa_cli add_network
    wpa_cli set_network 0 ssid $1
    wpa_cli set_network 0 psk $2
    wpa_cli enable_network 0

    sleep 20

    echo "###########################################"
    busybox ifconfig wlan0
    echo "###########################################"

    # Get ip address from WiFi interface
    ip_address_line=`busybox ifconfig wlan0 | grep "inet addr"`
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
    svc wifi disable
    sleep 30
    busybox ifconfig eth0 up
    sleep 30

    pass_test
}

# run the tests
test_enable_wifi
test_disable_wifi
test_connect_to_ap $1 $2
# clean exit so lava-test can trust the results
exit 0