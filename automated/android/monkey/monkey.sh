#!/bin/sh

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

HOST_OUTPUT="$(pwd)/output"
DEVICE_OUTPUT="/data/monkey-test"
RESULT_FILE="${HOST_OUTPUT}/result.txt"

usage() {
    echo "Usage: $0 [-s <sn>] [-b <blacklist>] [-p <monkeypara>] [-e <eventnum>] [-t <throttle>]" 1>&2
    exit 0
}

####some default parameters
BLACKLIST="setting"
MONKEYPARA="--ignore-timeouts --ignore-security-exceptions --kill-process-after-error -v -v -v"
EVENTNUM="1000"
THROTTLE="200"

while getopts "s:b:p:e:t:" opt; do
    case "$opt" in
        s) SN="${OPTARG}" ;;
        b) BLACKLIST="${OPTARG}" ;;
        p) MONKEYPARA="${OPTARG}" ;;
        e) EVENTNUM="${OPTARG}" ;;
        t) THROTTLE="${OPTARG}" ;;
        *) usage ;;
    esac
done

initialize_adb
install

[ -d "${HOST_OUTPUT}" ] && mv "${HOST_OUTPUT}" "${HOST_OUTPUT}-$(date +%Y%m%d%H%M%S)"
mkdir -p "${HOST_OUTPUT}"

#####read blacklist and write to blacklist.txt
BLACKLISTTXT="${HOST_OUTPUT}/blacklist.txt"
arr=$(echo "$BLACKLIST"|tr "," "\n")
for s in "$arr"
do
    echo "$s"
    echo "$s" >> "$BLACKLISTTXT"
done

adb -s "${SN}" push "$BLACKLISTTXT" /data
BLACKLIST="/data/blacklist.txt"
info_msg "About to run dd monkey test on device ${SN}"

adb -s "${SN}" shell monkey "${MONKEYPARA}" --pkg-blacklist-file "${BLACKLIST}" --throttle "${THROTTLE}" "${EVENTNUM}" 2>&1 \
    | tee "${HOST_OUTPUT}/monkey-test-output.txt"

grep "Monkey finished" "${HOST_OUTPUT}/monkey-test-output.txt"
check_return "monkey-test"

