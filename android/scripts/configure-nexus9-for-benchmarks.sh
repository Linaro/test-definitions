#!/bin/bash
set -x
echo "configuring Nexus9 on: $IPADDR"
adb -s $IPADDR wait-for-device
adb -s $IPADDR shell dumpsys battery
adb -s $IPADDR shell stop
adb -s $IPADDR shell "echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
sleep 2
adb -s $IPADDR shell "echo  1224000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
sleep 2
adb -s $IPADDR shell "echo  1224000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
sleep 2
