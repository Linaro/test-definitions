#!/bin/sh
#
# USB test cases for Linux Linaro ubuntu
#
# Copyright (C) 2012 - 2014, Linaro Limited.
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
#

# generate test result with lava-test-case
test_result(){
if [ $? -eq 0 ]; then
    lava-test-case $1 --result pass
else
    lava-test-case $1 --result fail
fi
}

# get the usb devices/hubs list
echo "========"
lsusb
test_result list-all-usb-devices

# examine all usb devices/hubs
if [ -d /dev/bus/usb/ ]; then
    for bus in `ls /dev/bus/usb/`; do
        for device in `ls /dev/bus/usb/$bus/`; do
            echo "========"
            echo "Bus $bus, device $device"
            lsusb -D /dev/bus/usb/$bus/$device
            status=$?

            if [ $status -ne 0 ]; then
                echo "Bus$bus-Device$device examination failed"
                break 2
            fi

        done
    done

    if [ $status -eq 0 ]; then
        lava-test-case examine-all-usb-devices --result pass
    else
        lava-test-case examine-all-usb-devices --result fail
    fi

else
    echo "/dev/bus/usb/ not exists"
    lava-test-case examine-all-usb-devices --result fail
fi

# print supported usb protocols
echo "========"
if [ -z "`lsusb -v | grep -i bcdusb`" ]; then
    lava-test-case print-supported-protocols --result fail
else
    lsusb -v | grep -i bcdusb | sort | uniq
    test_result print-supported-protocols
fi

# print supported speeds
echo "========"
if [ -z "`lsusb -t`" ]; then
    lava-test-case print-supported-speeds --result fail
else
    lsusb -t
    test_result print-supported-speeds
fi
# clean exit so lava-test can trust the results
exit 0
