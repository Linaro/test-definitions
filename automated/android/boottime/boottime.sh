#!/bin/sh -e
# shellcheck disable=SC1091

ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
OPERATION="COLLECT"
COLLECT_NO="1"
OUTPUT="$(pwd)/output"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-o <COLLECT|ANALYZE>] [-n <collect_no>]" 1>&2
    exit 1
}

while getopts ":s:t:o:n:" o; do
  case "$o" in
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    o) OPERATION="${OPTARG}" ;;
    n) COLLECT_NO="${OPTARG}" ;;
    *) usage ;;
  esac
done

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

adb_push "./device-script.sh" "/data/local/tmp/"
info_msg "device-${ANDROID_SERIAL}: About to run boottime ${OPERATION} ${COLLECT_NO}..."
adb shell "/data/local/tmp/device-script.sh ${OPERATION} ${COLLECT_NO}" \
    | tee "${OUTPUT}/device-stdout.log"

adb_pull "/data/local/tmp/boottime/" "${OUTPUT}/device-boottime"
cp "${OUTPUT}/device-boottime/result.txt" "${OUTPUT}/"
if [ "${OPERATION}" = "ANALYZE" ]; then
    adb_pull "/data/local/tmp/boottime.tgz" "${OUTPUT}"
fi
