#!/bin/bash
#
# wlan download test case
#
# Copyright (C) 2012 - 2016, Linaro Limited.
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
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>
# Description:
# Download a file via wlan interface from know location
# validate the file by using md5sum with known md5sum
#

set -e

URL=$1
MD5SUM_CHECK=$2
OUTPUT_FILE_NAME="output_file"
MD5SUM=`which md5sum`
GET_MD5SUM=""
WLAN_INTERFACE=""
OLD_GATEWAY_IP=""
OLD_GATEWAY_INTERFACE=""
WLAN_GATEWAY_IP=""
WLAN_GATEWAY=""
RET=0

pre_setup() {
    # Print ifconfig to know available interfaces
    ip addr

    # Make sure that rp_filter is set to 0
    echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
    echo 0 > /proc/sys/net/ipv4/conf/default/rp_filter
}

check_wlan_interface() {
    # Check wlan interface state
    WLAN_INTERFACE_ARG=$1
    if [ -z $WLAN_INTERFACE_ARG ]; then
       echo "No wireless interface found on the device"
       echo "wlan-download-testcase=fail"
       RET=1
       exit $RET
    else
       ip addr show $WLAN_INTERFACE_ARG | grep "state UP"
       if [ $? -eq 0 ] ; then
          echo "wireless interface state UP"
          echo "wireless-interface-state=pass"
        else
          echo "wireless interface state DOWN"
          echo "wireless-interface-state=fail"
          RET=1
          exit $RET
       fi
    fi
}

get_interface_and_ipaddr() {
    # Assume eth and wlan are up and running
    WLAN_INTERFACE=`ls -1d /sys/class/net/*/wireless | awk -F / '{print($5)}' | head -1`
    echo wlan interface $WLAN_INTERFACE
    check_wlan_interface $WLAN_INTERFACE

    OLD_GATEWAY_IP=`ip route list | grep default |awk '{print $3}'`
    echo old gate way ip $OLD_GATEWAY_IP

    OLD_GATEWAY_INTERFACE=`ip route list | grep default |awk '{print $5}'`
    echo old gate way interface $OLD_GATEWAY_INTERFACE

    WLAN_GATEWAY_IP=`ip route list | grep $WLAN_INTERFACE | tail -1 | awk '{print $1}' | cut -f1 -d'/'`
    echo wlan gateway IP $WLAN_GATEWAY_IP

    WLAN_GATEWAY=`echo $WLAN_GATEWAY_IP | awk -F'.' '{$NF=1; print}' OFS="."`
    echo wlan gateway $WLAN_GATEWAY
}

del_primary_route() {
    ip route del default dev $OLD_GATEWAY_INTERFACE via $OLD_GATEWAY_IP
}

add_wlan_route() {
    ip route add default dev $WLAN_INTERFACE via $WLAN_GATEWAY
}

del_wlan_route() {
    ip route del default dev $WLAN_INTERFACE via $WLAN_GATEWAY
}

set_back_primary_route() {
    ip route add default dev $OLD_GATEWAY_INTERFACE via $OLD_GATEWAY_IP
}

download_via_wlan() {
    which curl
    if [ $? -eq 0 ] ; then
        curl -# --connect-timeout 1800 $URL > $OUTPUT_FILE_NAME
        if [ $? -eq 0 ] ; then
           echo "curl-file-download=pass"
        else
           echo "please validate provided url" $URL
           echo "curl-file-download=fail"
           RET=1
        fi
    else
        echo "curl command not found test exit"
        echo "curl-cmd-not-found=fail"
        RET=1
    fi
}

validate_check_sum() {
    # Get md5sum of output_file
    GET_MD5SUM=`$MD5SUM $OUTPUT_FILE_NAME | awk '{print $1}'`
    echo "GET_MD5SUM is $GET_MD5SUM"
    if [ "$MD5SUM_CHECK" = $GET_MD5SUM ] ; then
        echo "md5-checksum=pass"
        echo "wlan-download-testcase=pass"
    else
        echo "md5-checksum=fail"
        echo "wlan-download-testcase=fail"
        RET=1
    fi
}

# Prerequisite
pre_setup
get_interface_and_ipaddr
del_primary_route
add_wlan_route

# Running Test
download_via_wlan
validate_check_sum

# Set back to original state
del_wlan_route
set_back_primary_route

exit $RET
