#!/bin/sh -e
# shellcheck disable=SC1091

BOOT_TIMEOUT="300"
OPERATION="COLLECT"
COLLECT_NO="1"
OUTPUT="$(pwd)/output"
SKIP_INSTALL='true'

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

usage() {
    echo "Usage: $0 [-S skip_install <true|false>] [-t <boot_timeout>] [-o <COLLECT|ANALYZE>] [-n <collect_no>]" 1>&2
    exit 1
}

while getopts ":S:t:o:n:v:" o; do
  case "$o" in
    S) SKIP_INSTALL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    o) OPERATION="${OPTARG}" ;;
    n) COLLECT_NO="${OPTARG}" ;;
    v) ANDROID_VERSION="${OPTARG}" ;;
    *) usage ;;
  esac
done

install_deps 'curl tar xz-utils usbutils' "${SKIP_INSTALL}"

create_out_dir "${OUTPUT}"

# LAVA itself will begin the test only after reaching to prompt.
# It is safe to report that system has booted to prompt
echo "BOOT_TO_CONSOLE pass" > ./boot_result.txt

initialize_adb
adb_root
# wait till boot completed
wait_boot_completed "${BOOT_TIMEOUT}"

echo "BOOT_TO_UI pass" >> boot_result.txt

mv boot_result.txt output/
f_device_script_name="device-script.sh"
if [ -n "${ANDROID_VERSION}" ] && [ "X${ANDROID_VERSION}" = "Xmaster" ]; then
    f_device_script_name="device-script-master.sh"
fi
adb_push "./${f_device_script_name}" "/data/local/tmp/"

info_msg "device-${ANDROID_SERIAL}: About to run boottime ${OPERATION} ${COLLECT_NO}..."
adb shell "/data/local/tmp/${f_device_script_name} ${OPERATION} ${COLLECT_NO}" \
    | tee "${OUTPUT}/device-stdout.log"

adb_pull "/data/local/tmp/boottime/" "${OUTPUT}/device-boottime"
cp "${OUTPUT}/device-boottime/result.txt" "${OUTPUT}/"
if [ "${OPERATION}" = "ANALYZE" ]; then
    adb_pull "/data/local/tmp/boottime.tgz" "${OUTPUT}"
fi
