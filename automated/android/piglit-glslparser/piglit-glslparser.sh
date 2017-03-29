#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/piglit-glslparser.log"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

parse_common_args "$@"
initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

adb_push "./device-script.sh" "/data/local/tmp/piglit-glslparser/"
info_msg "device-${ANDROID_SERIAL}: About to run piglit-glslparser..."
adb shell "echo /data/local/tmp/piglit-glslparser/device-script.sh 2>&1 | su" | tee "${LOGFILE}"

grep -E "glslparser /data/piglit/glslparser/.+: (pass|fail|skip)" "${LOGFILE}" \
    | sed 's/://g' \
    | awk '{printf("%s %s\n", $2, $3)}' >> "${RESULT_FILE}"
