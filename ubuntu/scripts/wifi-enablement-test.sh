#!/bin/bash
#
# Wifi Enablement test cases
#
# Copyright (C) 2012, Linaro Limited.
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
# Author: Ricardo Salveti <rsalveti@linaro.org>
#         Alexander Sack <asac@linaro.org>
#
# TODO: Improve argument parsing

# arguments: SSID, PSK, WPA DRIVER
SSID="$1"
PSK="$2"
DRIVER="$3"
IFACE=""
GCTRLIFACE="/var/run/wpasupplicant-global-lava-test"
LCTRLIFACE="/var/run/wpasupplicant-local-lava-test"
PFDHCLIENT="/var/run/dhclient-lava-test.pid"
SAMPLEFILE="http://readyshare.routerlogin.net/shares/USB_Storage/samplemedia.linaro.org/mpeg4/big_buck_bunny_1080p_MPEG4_MP3_25fps_7600K.AVI"

source include/sh-test-lib

test_setup() {
    service network-manager stop 1>&2
    killall -9 wpa_supplicant 1>&2
    killall -9 dhclient 1>&2
    [ "x$IFACE" != "x" ] && ifconfig $IFACE 0.0.0.0
    rm -f $GCTRLIFACE
    rm -f $LCTRLIFACE
    rm -f $PFDHCLIENT
}

test_restore() {
    killall -9 wpa_supplicant 1>&2
    killall -9 dhclient 1>&2
    [ "x$IFACE" != "x" ] && ifconfig $IFACE 0.0.0.0
    rm -f $GCTRLIFACE
    rm -f $LCTRLIFACE
    rm -f $PFDHCLIENT
    service network-manager start 1>&2
}

## Test case definitions

# Has wireless device
test_has_wireless_device() {
    TEST="has_wireless_device_${SSID}_${DRIVER}"

    iwconfig 1>&2

    # for now grab just the first interface
    IFACE=`iwconfig | grep '^[a-zA-Z]*[0-9]*.*IEEE.*ESS.*$' \
            | head -n1 | sed -e 's/[ ].*$//'`
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    pass_test
}

# Able to put interface down
test_able_put_iface_down() {
    TEST="able_put_iface_down_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    ifconfig $IFACE down
    check_return_fail "unable to put interface $IFACE down" && return 1

    pass_test
}

# Able to put interface up
test_able_put_iface_up() {
    TEST="able_put_iface_up_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    ifconfig $IFACE up
    check_return_fail "unable to put interface $IFACE up" && return 1

    pass_test
}

# Can scan for APs
test_able_scan_aps() {
    TEST="able_scan_aps_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    # should work for at least 3 times in a row
    for i in 1 2 3; do
        iwlist $IFACE scan 1>&2
        check_return_fail "failed to scan for aps" && return 1
        sleep 3
    done

    pass_test
}

# Can find target AP
test_able_scan_find_target_ap() {
    TEST="able_scan_find_target_ap_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    iwlist $IFACE scan | grep -q "ESSID:\"$SSID\""
    check_return_fail "unable to find ESSID '$SSID' while scanning for APs" && return 1

    pass_test
}

# Can start wpa supplicant
test_able_start_wpa_supplicant() {
    TEST="able_start_wpa_supplicant_${SSID}_${DRIVER}"

    /sbin/wpa_supplicant -dd -B -g $GCTRLIFACE 1>&2
    check_return_fail "fail to start wpa_supplicant" && return 1

    if [ ! -S $GCTRLIFACE ]; then
        fail_test "fail to create wpa supplicant global ctrl_interface"
        return 1
    fi

    pass_test
}

# Can add interface wpa supplicant
test_able_add_iface_wpa_supplicant() {
    TEST="able_add_iface_wpa_supplicant_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    ret=$(/sbin/wpa_cli -g $GCTRLIFACE interface_add $IFACE "" $DRIVER $LCTRLIFACE)
    if ! echo ${ret} | egrep -q "OK$"; then
        fail_test "fail to add interface $IFACE with wpa_cli"
        return 1
    fi

    pass_test
}

# Can add network wpa supplicant
test_able_add_network_wpa_supplicant() {
    TEST="able_add_network_wpa_supplicant_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    /sbin/wpa_cli -p $LCTRLIFACE -i$IFACE add_network 1>&2
    check_return_fail "fail to add network with wpa_cli" && return 1

    pass_test
}

# Can config network wpa supplicant
test_able_set_network_wpa_supplicant() {
    TEST="able_set_network_wpa_supplicant_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    ret=$(/sbin/wpa_cli -p $LCTRLIFACE -i$IFACE set_network 0 ssid \""$SSID"\")
    if [ "x$ret" != "xOK" ]; then
        fail_test "fail to set the network SSID '$SSID' with wpa_cli"
        return 1
    fi
    ret=$(/sbin/wpa_cli -p $LCTRLIFACE -i$IFACE set_network 0 psk \""$PSK"\")
    if [ "x$ret" != "xOK" ]; then
        fail_test "fail to set the network PSK '$SSID' with wpa_cli"
        return 1
    fi

    pass_test
}

# Can enable network wpa supplicant
test_able_enable_network_wpa_supplicant() {
    TEST="able_enable_network_wpa_supplicant_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    ret=$(/sbin/wpa_cli -p $LCTRLIFACE -i$IFACE enable_network 0)
    if [ "x$ret" != "xOK" ]; then
        fail_test "fail to enable the network with wpa_cli"
        return 1
    fi

    pass_test
}

# Can associate at the AP
test_able_associate_ap_wpa_supplicant() {
    TEST="able_associate_ap_wpa_supplicant_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    i=1
    ret=FAIL
    while [ $i -le 20 ]; do
        sleep 1
        if /sbin/wpa_cli -p $LCTRLIFACE -i$IFACE status \
                | grep -q "wpa_state=COMPLETED"; then
            ret=OK
            break
        fi
        i=$((i+1))
    done

    if [ "x$ret" != "xOK" ]; then
        fail_test "fail to associate to AP"
        return 1
    fi

    pass_test
}

# Can grap ip with dhclient
test_able_get_ip_dhclient() {
    TEST="able_get_ip_dhclient_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    /sbin/dhclient -pf $PFDHCLIENT $IFACE 1>&2
    /sbin/ifconfig -a 1>&2

    if [ ! -f $PFDHCLIENT ]; then
        fail_test "fail get a valid ip address from AP"
        return 1
    fi

    pass_test
}

# Can transfer a file and use the network
test_able_transfer_file_network() {
    TEST="able_transfer_file_${SSID}_${DRIVER}"
    [ "x$IFACE" == "x" ] && fail_test "No valid wireless interface found" && return 1

    /usr/bin/wget --tries=3 --output-document=/tmp/samplefile ${SAMPLEFILE} 1>&2
    check_return_fail "fail to download $SAMPLEFILE" && return 1

    pass_test
}

# Can terminate wpa supplicant ip with dhclient
test_able_terminate_wpa_supplicant() {
    TEST="able_terminate_wpa_supplicant_${SSID}_${DRIVER}"

    # take a nap before closing wpa supplicant down
    sleep 5
    ret=$(/sbin/wpa_cli -g $GCTRLIFACE terminate)
    if ! echo ${ret} | egrep -q "OK$"; then
        fail_test "fail to terminate wpa supplicant"
        return 1
    fi

    pass_test
}

# check we're root
if ! check_root; then
    error_msg "Please run the test case as root"
fi

# test to check if we have an interface
test_has_wireless_device

# setup the environment
test_setup

# run the tests
test_able_put_iface_down
test_able_put_iface_up
test_able_scan_aps
test_able_scan_find_target_ap
test_able_start_wpa_supplicant
test_able_add_iface_wpa_supplicant
test_able_add_network_wpa_supplicant
test_able_set_network_wpa_supplicant
test_able_enable_network_wpa_supplicant
test_able_associate_ap_wpa_supplicant
test_able_get_ip_dhclient
test_able_transfer_file_network
test_able_terminate_wpa_supplicant

# get back the environment to previous state
test_restore
