#!/bin/sh

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

HOST_OUTPUT="$(pwd)/output"
DEVICE_OUTPUT="/data/monkey-test"
RESULT_FILE="${HOST_OUTPUT}/result.txt"

usage() {
    echo "Usage: $0 [-b <blacklist>] [-p <monkeypara>] [-e <eventnum>] [-t <throttle>]" 1>&2
    echo "You can input no parameter and use the default value:" 1>&2
    echo "blacklist: "setting"" 1>&2
    echo "monkeypara: "--ignore-timeouts --ignore-security-exceptions --kill-process-after-error -v -v -v"" 1>&2
    echo "eventnum: 500" 1>&2
    echo "throrrle: 200" 1>&2
    exit 0
}

####some default parameters
BLACKLIST="setting"
MONKEYPARA="--ignore-timeouts --ignore-security-exceptions --kill-process-after-error -v -v -v"
EVENTNUM="1000"
THROTTLE="200"
SN=""

while getopts "s:b:p:e:t:h" opt; do
    case "$opt" in
        s) SN="${OPTARG}" ;;
        b) BLACKLIST="${OPTARG}" ;;
        p) MONKEYPARA="${OPTARG}" ;;
        e) EVENTNUM="${OPTARG}" ;;
        t) THROTTLE="${OPTARG}" ;;
        h) usage ;;
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

if [ -z $SN ];then
    adb="adb"
else
    adb="adb -s "${SN}""
fi
echo "${adb}"

$adb push "$BLACKLISTTXT" /data
BLACKLIST="/data/blacklist.txt"
info_msg "About to run dd monkey test on device ${SN}"

$adb shell monkey "${MONKEYPARA}" --pkg-blacklist-file "${BLACKLIST}" --throttle "${THROTTLE}" "${EVENTNUM}" 2>&1 \
    | tee "${HOST_OUTPUT}/monkey-test-output.txt"

grep "Monkey finished" "${HOST_OUTPUT}/monkey-test-output.txt"
check_return "monkey-test"

