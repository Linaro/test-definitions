#!/bin/bash

. ../../lib/sh-test-lib
GPIOD_PATH=${1:-"/opt/libgpiod/bin/"}
LOGFILE=tmp.txt
RESULT_FILE=result.txt

export PATH="${GPIOD_PATH}:$PATH"

trap 'exit_cleanup' EXIT
trap '_warn "interrupted, cleaning up..."; exit_cleanup; exit 1' INT

mount_debugfs

gpiod-test 2>&1| tee tmp.txt
./parse-output.py < "${LOGFILE}" | tee -a "${RESULT_FILE}"
