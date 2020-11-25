#!/bin/sh -ex
# shellcheck disable=SC1091

BOOT_TIMEOUT="300"
OPERATION="COLLECT"
COLLECT_NO="1"
OUTPUT="$(pwd)/output"
SKIP_INSTALL='false'

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

#install_deps 'curl tar xz-utils usbutils' "${SKIP_INSTALL}"

create_out_dir "${OUTPUT}"

# LAVA itself will begin the test only after reaching to prompt.
# It is safe to report that system has booted to prompt
echo "BOOT_TO_CONSOLE pass" > ${OUTPUT}/boot_result.txt

initialize_adb # ANDROID_SERIAL exported here
# wait till boot completed
wait_boot_completed "${BOOT_TIMEOUT}"

lsusb -v |tee output/lsusb-v-before-adb-root.txt
adb_root
lsusb -v |tee output/lsusb-v-before-reboot.txt
[ -f ./debug-fastboot.sh ] && ./debug-fastboot.sh
adb shell "echo u > /proc/sysrq-trigger"
adb shell "echo b > /proc/sysrq-trigger"
echo "BOOT_REBOOT pass" > ${OUTPUT}/boot_result.txt
sleep 60
lsusb -v |tee output/lsusb-v-before-fastboot.txt
fastboot devices
num_fastboot_devices="$(fastboot devices |wc -l)"
if [ "${num_fastboot_devices}" -ne 1 ]; then
    [ -f ./debug-fastboot.sh ] && ./debug-fastboot.sh
    echo "BOOT_AGAIN_AFTER_REBOOT fail" > ${OUTPUT}/boot_result.txt
    echo  "No fastboot devices listed"
else
    timeout 300 fastboot boot /lava-lxc/*boot*.img
    timeout 300 adb wait-for-device
    lsusb -v |tee output/lsusb-v-after-booted.txt
    wait_boot_completed "${BOOT_TIMEOUT}"
    echo "BOOT_AGAIN_AFTER_REBOOT pass" > ${OUTPUT}/boot_result.txt
fi
