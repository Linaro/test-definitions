#!/bin/sh -x
while true;
do
    date
    echo "output of lsusb"
    lsusb
    echo "output of adb devices"
    adb devices
    echo "output of fastboot devices"
    fastboot devices
    echo "end for the debug commands"
    sleep 60
done
