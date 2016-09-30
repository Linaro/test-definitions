#!/bin/sh

HOST_OUTPUT="$(pwd)/output"
DEVICE_OUTPUT="/data/monkey-test"
RESULT_FILE="${HOST_OUTPUT}/result.txt"
 
usage() {
    echo "Usage: $0 [-s <sn>] [-b <blacklist>] [-p <monkeypara>] [-e <eventnum>] [-t <throttle>]" 1>&2
    exit 1
}

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

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

parse_output(){
    local test=$1
    local test_case_id="${test}"
    local result=False
    if ! [ -f "${HOST_OUTPUT}/${test}-output.txt" ]; then
        warn_msg "${test} result file missing"
        return
    fi
  
    while read line; do
        if echo "${line}" | egrep -q "Monkey finished"; then
            result=True
        fi

    done < "${HOST_OUTPUT}/${test}-output.txt"
 
    if [ "$result" = True ]; then
        echo "${test_case_id} pass" > $RESULT_FILE
    else 
        echo "${test_case_id} fail" > $RESULT_FILE
    fi

}

initialize_adb
detect_abi

[ -d "${HOST_OUTPUT}" ] && mv "${HOST_OUTPUT}" "${HOST_OUTPUT}-$(date +%Y%m%d%H%M%S)"
mkdir -p "${HOST_OUTPUT}"

#####read blacklist and write to blacklist.txt
BLACKLISTTXT="${HOST_OUTPUT}/blacklist.txt"
arr=$(echo $BLACKLIST|tr "," "\n")
for s in $arr
do  
    echo $s
    echo "$s" >> $BLACKLISTTXT
done

adb -s ${SN} push $BLACKLISTTXT /data
BLACKLIST="/data/blacklist.txt"
info_msg "About to run dd monkey test on device ${SN}"

adb -s ${SN} shell monkey ${MONKEYPARA} --pkg-blacklist-file ${BLACKLIST} --throttle ${THROTTLE} ${EVENTNUM} 2>&1 \
    | tee "${HOST_OUTPUT}/monkey-test-output.txt"
 
parse_output "monkey-test"

