#!/bin/sh -e
# Busybox smoke tests.

OUTPUT="$(pwd)/output"

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

initialize_adb
wait_boot_completed "300"
create_out_dir "${OUTPUT}"

adb_push "./device-script.sh" "/data/local/tmp/bin/"

adb shell '/data/local/tmp/bin/device-script.sh 2>&1' \
                          | tee "${OUTPUT}/device-stdout.log"

adb_pull "/data/local/tmp/busybox/result.txt" "${OUTPUT}/"
