#!/bin/sh -ex
# shellcheck disable=SC1091

BOOT_TIMEOUT="300"
OPERATION="COLLECT"
COLLECT_NO="1"
OUTPUT="$(pwd)/output"
SKIP_INSTALL='true'

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

install_deps 'curl tar xz-utils usbutils' "${SKIP_INSTALL}"

create_out_dir "${OUTPUT}"

# LAVA itself will begin the test only after reaching to prompt.
# It is safe to report that system has booted to prompt
echo "BOOT_TO_CONSOLE pass" > ./boot_result.txt

initialize_adb # ANDROID_SERIAL exported here
lsusb -v |tee output/lsusb-v-before-adb-root.txt
adb_root
# wait till boot completed
wait_boot_completed "${BOOT_TIMEOUT}"
lsusb -v |tee output/lsusb-v-before-reboot.txt
adb shell "echo u > /proc/sysrq-trigger"
adb shell "echo b > /proc/sysrq-trigger"
sleep 30
lsusb -v |tee output/lsusb-v-before-fastboot.txt
fastboot devices
fastboot boot /lava-lxc/*boot*.img
adb wait-for-device
lsusb -v |tee output/lsusb-v-after-booted.txt
wait_boot_completed "${BOOT_TIMEOUT}"
