#!/bin/sh

#set -x

DURATION=$1
LOGFILE=$2
RESULT_PASS_FILE="./trinity-result-pass"

if [ -f ${RESULT_PASS_FILE} ]; then
	rm -f ${RESULT_PASS_FILE}
fi
if [ -f zip_log ]; then
	rm -f zip_log
fi
mkfifo zip_log
(gzip -c < zip_log > ${LOGFILE}) &

echo -e "DURATION: ${DURATION}"
# Send SIGKILL to trinity processes after DURATION seconds
(sleep ${DURATION} ; for p in `pgrep trinity`;do [ ! -f ${RESULT_PASS_FILE} ] && touch ${RESULT_PASS_FILE} ; kill -9 $p; done) &
# Remove non-printable ASCII characters by tr
./trinity/trinity -m --dangerous | tr -cd '\11\12\15\40-\176' | tee zip_log

if [ -f ${RESULT_PASS_FILE} ]; then
    exit 0
else
    exit 1
fi
