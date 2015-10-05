adb wait-for-device
adb shell stop
adb shell "echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
adb shell "echo  2295000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq"
adb shell "echo  2295000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq"
