#!/bin/bash
#
# Bluetooth Enablement test cases
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
#
# TODO: Add support for pairing

SERV_BD_ID="LAVA-Bluetooth01"
SERV_BD_ADDR="00:15:83:15:A3:10"
IFACE=""
IFACE_ADDR=""

source include/sh-test-lib

## Test case definitions

# Has bt adapter
test_has_valid_bt_adapter() {
    TEST="has_valid_bt_adapter"

    # show interfaces at stderr, so it can be useful at lava's dashboard
    hciconfig 1>&2

    # for now grab just the first device
    TESTIFACE=`hciconfig | head -n 1 | cut -d':' -f1`
    [ "x$TESTIFACE" == "x" ] && fail_test "No bluetooth adapter found" && return 1

    # check if it can put the interface up
    hciconfig $TESTIFACE up
    check_return_fail "Unable to open and initialize HCI device ($TESTIFACE)" && return 1

    # set piscan at the bt interface
    hciconfig $TESTIFACE piscan
    check_return_fail "Unable to enable page and inquire scan ($TESTIFACE)" && return 1

    # make sure the bt interface has a valid bd address
    TESTIFACE_ADDR=`hciconfig $TESTIFACE | grep "BD Address" | awk '{print $3}'`
    [ "x$TESTIFACE_ADDR" == "x00:00:00:00:00:00" ] && fail_test "Adapter's mac addr is null" && return 1

    # set IFACE as a valid bt interface
    IFACE=$TESTIFACE
    IFACE_ADDR=$TESTIFACE_ADDR

    pass_test
}

test_bluez_adapter_get_address() {
    TEST="bluez_adapter_get_address"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    addr=`bluez-test-adapter address`
    [ "x$addr" == "x" ] && fail_test "Bluez: failed to get adapter's address" && return 1
    [ "$addr" != "$IFACE_ADDR" ] && fail_test "Bluez: adapter addr != hciconfig addr" && return 1

    pass_test
}

test_bluez_adapter_set_name() {
    TEST="bluez_adapter_set_name"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    # get original name
    orig_name=`bluez-test-adapter name`
    [ "x$orig_name" == "x" ] && fail_test "Bluez: failed to get adapter's orignal name" && return 1

    # set to custom name
    bluez-test-adapter name linaro-bt-test
    check_return_fail "Bluez: unable to set device's name" && return 1

    # get custom name
    custom_name=`bluez-test-adapter name`
    [ "x$custom_name" == "x" ] && fail_test "Bluez: failed to get adapter's custom name" && return 1
    [ "$custom_name" != "linaro-bt-test" ] && fail_test "Bluez: adap name != custom one" && return 1

    # set back to original
    bluez-test-adapter name $orig_name
    check_return_fail "Bluez: unable to set device original name" && return 1

    pass_test
}

test_bluez_adapter_powered_on_off() {
    TEST="bluez_adapter_powered_on_off"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    # assume powered by default
    for i in 1 2 3; do
        bluez-test-adapter powered off
        check_return_fail "Bluez: failed to set powered off" && return 1
        sleep 2
        bluez-test-adapter powered on
        check_return_fail "Bluez: failed to set powered on" && return 1
        sleep 2
    done

    pass_test
}

test_bluez_adapter_pairable_on_off() {
    TEST="bluez_adapter_pairable_on_off"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    # assume pairable on by default
    for i in 1 2 3; do
        bluez-test-adapter pairable off
        check_return_fail "Bluez: failed to set pairable off" && return 1
        sleep 2
        bluez-test-adapter pairable on
        check_return_fail "Bluez: failed to set pairable on" && return 1
        sleep 2
    done

    pass_test
}

test_bluez_adapter_discoverable_on_off() {
    TEST="bluez_adapter_discoverable_on_off"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    # assume discoverable on by default
    for i in 1 2 3; do
        bluez-test-adapter discoverable off
        check_return_fail "Bluez: failed to set discoverable off" && return 1
        sleep 5
        bluez-test-adapter discoverable on
        check_return_fail "Bluez: failed to set discoverable on" && return 1
        sleep 5
    done

    pass_test
}

test_bluez_hci_discovery() {
    TEST="bluez_hci_discovery"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    bluez-test-discovery 1>&2
    check_return_fail "Bluez: failed to scan for bt devices" && return 1
    hcitool -i $IFACE scan 1>&2
    check_return_fail "Hcitool: failed to scan for bt devices" && return 1

    pass_test
}

test_bluez_discovery_find_target_ap() {
    TEST="bluez_discovery_find_target_ap"
    [ "x$IFACE" == "x" ] && fail_test "No valid bluetooth adapter found" && return 1

    scan_out=`bluez-test-discovery`
    if ! echo $scan_out | grep -q "Name = $SERV_BD_ID"; then
        fail_test "Bluez: failed to find target AP ($SERV_BD_ID) when scanning"
        return 1
    fi
    if ! echo $scan_out | grep -q "[ $SERV_BD_ADDR ]"; then
        fail_test "Bluez: failed to find target AP addr ($SERV_BD_ADDR) when scanning"
        return 1
    fi

    pass_test
}

# check we're root
if ! check_root; then
    error_msg "Please run the test case as root"
fi

# test to check if we have an bt adapter
test_has_valid_bt_adapter

# run the tests

## using bluez-tests
test_bluez_adapter_get_address
test_bluez_adapter_set_name
test_bluez_adapter_powered_on_off
test_bluez_adapter_pairable_on_off
test_bluez_adapter_discoverable_on_off
test_bluez_hci_discovery
test_bluez_discovery_find_target_ap

# exit with a good return code, so lava believes it finished OK
exit 0
