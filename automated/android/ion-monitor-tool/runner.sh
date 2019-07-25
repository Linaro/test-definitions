#!/bin/bash

set -ex

HEAP="/sys/kernel/debug/ion/display"
REPEAT="5"
CLEAR="true"
SECURE="false"
UHD="false"

usage() {
    echo "Usage: $0 [-h heap path] [-r number of repeat] [-c include clear playback] [-s include secure playback] [-u include UHD playback]" 1>&2
    exit 1
}

while getopts h:r:c:s:u: option
do
case "${option}"
in
h) HEAP=${OPTARG};;
r) REPEAT=${OPTARG};;
c) CLEAR=${OPTARG};;
s) SECURE=${OPTARG};;
u) UHD=${OPTARG};;
*) usage;;

esac
done

COMMAND="cd /data && ./ion-monitor-tool.bin -f ${HEAP} -r ${REPEAT}"

if [ "$CLEAR" = "true" ]; then
    COMMAND="${COMMAND} -c"
fi

if [ "$SECURE" = "true" ]; then
    COMMAND="${COMMAND} -s"
fi

if [ "$UHD" = "true" ]; then
    COMMAND="${COMMAND} -u"
fi

adb shell "${COMMAND}" | tee ./stdout.log

<./stdout.log grep RESULT | awk '{print $2" "$3""}' | sed "s/FAIL/fail/; s/PASS/pass/" > results.txt
while read -r line
do
    TEST_CASE=$(echo "${line}" | awk '{print $1}')
    RESULT=$(echo "${line}" | awk '{print $2}')
    echo "<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=${TEST_CASE} RESULT=${RESULT}>"
done < "results.txt"

exit 0
