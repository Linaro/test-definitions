#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/piglit-gles2.log"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

parse_common_args "$@"
initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

adb_push "./device-script.sh" "/data/local/tmp/piglit-gles2/"
info_msg "device-${ANDROID_SERIAL}: About to run piglit-gles2..."
adb shell "/data/local/tmp/piglit-gles2/device-script.sh" | tee "${LOGFILE}"

grep -E ".*: (pass|fail|skip)" "${LOGFILE}" \
    | sed 's/://g' \
    | awk '{printf("%s %s\n", $1, $2)}' >> "${RESULT_FILE}"
