#!/bin/sh

# generate test result with lava-test-case
test_result(){
if [ $? -eq 0 ]
then
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
for bus in `ls /dev/bus/usb`; do
    for device in `ls /dev/bus/usb/$bus`; do
        echo "========"
        echo "Bus $bus, device $device"
        lsusb -D /dev/bus/usb/$bus/$device
    done
done
test_result examine-all-usb-devices

# print supported usb protocols
echo "========"
lsusb -v | grep -i bcdusb
test_result print-supported-protocols

# print supported speeds
echo "========"
lsusb -t
test_result print-supported-speeds

# clean exit so lava-test can trust the results
exit 0
