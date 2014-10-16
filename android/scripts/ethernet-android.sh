#!/system/bin/sh
#
# Ethernet test cases for Linaro Android
#
# Copyright (C) 2010 - 2014, Linaro Limited.
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

check_return_fail() {
    if [ $? -ne 0 ]; then
        fail_test "$1"
        return 0
    else
        return 1
    fi
}

fail_test() {
    local reason=$1
    echo "${TEST}: FAIL - ${reason}"
}

pass_test() {
    echo "${TEST}: PASS"
}

## Test case definitions
# Check Ethernet can be disabled or not
test_disable_ethernet() {
    TEST="disable_ethernet"

    echo `which busybox`
    busybox ifconfig eth0 down

    if [ $? -ne 0 ]; then
        fail_test "Ethernet disable failed"
        return 1
    fi

    sleep 20

    echo "###########################################"
    busybox ifconfig -a
    echo "###########################################"

    busybox ifconfig eth0 | grep "inet addr"

    if [ $? -ne 1 ]; then
        fail_test "Ethernet IP address still exists"
        return 1
    fi

    pass_test
}

# Check Ethernet can be enabled or not
test_enable_ethernet() {
    TEST="enable_ethernet"

    echo `which busybox`
    busybox ifconfig eth0 up

    if [ $? -ne 0 ]; then
        fail_test "Ethernet enable failed"
        return 1
    fi

    sleep 20

    echo "###########################################"
    busybox ifconfig -a
    echo "###########################################"

    busybox ifconfig eth0 | grep "inet addr"

    if [ $? -ne 0 ]; then
        fail_test "Ethernet IP not found"
        return 1
    fi

    pass_test
}

# Ethernet ping test
test_ethernet_ping() {
    TEST="ethernet_ping"

    echo `which busybox`
    busybox ifconfig eth0 up

    sleep 20

    echo "###########################################"
    busybox ifconfig -a
    echo "###########################################"

    busybox ifconfig eth0 | grep "inet addr"
    if [ $? -ne 0 ]; then
        fail_test "Ethernet IP not found"
        return 1
    fi

    # Get ip address from Ethernet interface
    ip_address_line=`busybox ifconfig eth0 | grep "inet addr"`
    echo $ip_address_line

    ip_address_element=$(echo $ip_address_line | awk '{print $2}')
    echo $ip_address_element

    ip_address=$(echo $ip_address_element | awk -F: '{print $2}')
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

    packet_loss=$(echo $packet_loss_line | awk '{print $6}')
    echo "The packet loss rate is $packet_loss"

    if [ "$packet_loss" != "0%" ]; then
        fail_test "Packet loss happened, rate is $packet_loss"
        return 1
    fi

    pass_test
}

# run the tests
test_disable_ethernet
test_enable_ethernet
test_ethernet_ping

# clean exit so lava-test can trust the results
exit 0
