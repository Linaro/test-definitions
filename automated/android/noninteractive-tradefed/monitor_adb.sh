#!/bin/sh -x
while true;
do
    date
    lsusb
    adb devices
    sleep 30
done
