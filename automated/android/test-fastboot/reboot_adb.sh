#!/bin/sh -x
while true; do
adb wait-for-device
adb reboot
done
