adb -s $IPADDR wait-for-device
adb -s $IPADDR shell stop
adb -s $IPADDR shell "echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
adb -s $IPADDR shell "echo  2295000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
adb -s $IPADDR shell "echo  2295000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
