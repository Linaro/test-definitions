#!/bin/sh -e
# shellcheck disable=SC1091

SKIP_INSTALL='false'
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
OPERATION="start"
BOOTCHART_TIME="120"
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

usage() {
    echo "Usage: $0 [-S <skip_install>] [-s <android_serial>] [-t <boot_timeout>] [-o <stop|start>] [-T <bootchart_time>]" 1>&2
    exit 1
}

while getopts ":S:s:t:o:T:" o; do
  case "$o" in
    S) SKIP_INSTALL="${OPTARG}" ;;
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    o) OPERATION="${OPTARG}" ;;
    T) BOOTCHART_TIME="${OPTARG}" ;;
    *) usage ;;
  esac
done

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"
install_deps 'curl tar xz-utils bootchart pybootchartgui' "${SKIP_INSTALL}"

adb_push "./device-script.sh" "/data/local/tmp/"
info_msg "device-${ANDROID_SERIAL}: About to run bootchart ${OPERATION}..."
adb shell "echo /data/local/tmp/device-script.sh ${OPERATION} ${BOOTCHART_TIME} | su" \
    | tee "${OUTPUT}/device-stdout.log"

grep -E "^[a-z_]+: (pass|fail)" "${OUTPUT}/device-stdout.log"\
    | sed 's/://g' >> "${RESULT_FILE}"

# Retrieving the collected data from target, and generate bootchart graphic.
if [ "${OPERATION}" = "stop" ]; then
    FILES="header proc_stat.log proc_ps.log proc_diskstats.log"
    for f in $FILES; do
        adb_pull "/data/local/tmp/bootchart/$f" "${OUTPUT}"
    done

    cd "${OUTPUT}"
    # shellcheck disable=SC2086
    tar -czf "bootchart.tgz" $FILES
    bootchart bootchart.tgz
    if [ -f bootchart.png ]; then
        report_pass "generate-bootchart-graphic"
    else
        report_fail "generate-bootchart-graphic"
    fi

    # Compress raw data and bootchart graphic for file uploading.
    tar caf "output-bootchart.tar.xz" bootchart.tgz bootchart.png
fi
