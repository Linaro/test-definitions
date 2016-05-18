#!/bin/bash
CPU_PATH="/sys/devices/system/cpu/cpu"

set_online() {
    local dirpath=$CPU_PATH$1/online
    adb -s $IPADDR shell "echo 1 > $dirpath"
}

set_offline() {
    local dirpath=$CPU_PATH$1/online
    adb -s $IPADDR shell "echo 0 > $dirpath"
}


all_small() {
    set_online 0; set_online 1; set_online 2; set_online 3;
    set_offline 4; set_offline 5;
}

all_big() {
    set_online 4; set_online 5;
    set_offline 0; set_offline 1; set_offline 2; set_offline 3;
}

all_online() {
    set_online 0; set_online 1; set_online 2;
    set_online 3; set_online 4; set_online 5;
}

show_cpu() {
    adb -s $IPADDR shell "cat /sys/devices/system/cpu/cpu*/online"
}


parse() {
    case $1 in
      small)
            all_small
      ;;
      big)
          all_big
      ;;
      default)
      ;;
    esac
}

set -x
echo "configuring Nexus5X on: $IPADDR"
adb -s $IPADDR wait-for-device
adb -s $IPADDR root
adb -s $IPADDR wait-for-device
adb -s $IPADDR shell stop
adb -s $IPADDR wait-for-device
for n in {0..5}; do
  adb -s $IPADDR shell "echo userspace > /sys/devices/system/cpu/cpu$n/cpufreq/scaling_governor"
  adb -s $IPADDR shell "echo 1000000 > /sys/devices/system/cpu/cpu$n/cpufreq/scaling_min_freq"
  adb -s $IPADDR shell "echo 1000000 > /sys/devices/system/cpu/cpu$n/cpufreq/scaling_max_freq"
done
parse "$@"
