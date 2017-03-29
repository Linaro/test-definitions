#!/bin/sh -e
# shellcheck disable=SC1091

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

parse_common_args "$@"
initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

info_msg "device-${ANDROID_SERIAL}: About to check meminfo..."
adb shell 'cat /proc/meminfo 2>&1' | tee "${OUTPUT}/proc-meminfo"
adb shell 'dumpsys meminfo 2>&1' | tee "${OUTPUT}/dumpsys-meminfo"

## Parse proc-meminfo
info_msg "Parsing results from proc-meminfo"
logfile="${OUTPUT}/proc-meminfo"
# Capacity info.
grep -E ".+: +[0-9]+ kB" "${logfile}" \
    | sed 's/://g' \
    | awk '{printf("%s pass %s kb\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"

# HugePages info.
grep "HugePages_" "${logfile}" \
    | sed 's/://g' \
    | awk '{printf("%s pass %s\n", $1, $2)}' \
    | tee -a "${RESULT_FILE}"

## Parse dumpsys-meminfo
# Total, Free, Used and Lost RAM.
info_msg "Parsing results from dumpsys-meminfo"
logfile="${OUTPUT}/dumpsys-meminfo"
grep -E "RAM: .+K" "${logfile}" \
    | sed 's/://g' \
    | awk '{printf("%s-%s pass %s K\n", $1, $2, substr($3, 1, length($3)-1))}' \
    | tee -a "${RESULT_FILE}"

# Detailed info on free RAM.
line=$(grep "Free RAM:" "${logfile}")
measurement=$(echo "${line}" | awk '{print substr($5, 1, length($5)-1)}')
add_metric "Free-RAM-cached-pss" "pass" "${measurement}" "K"
measurement=$(echo "${line}" | awk '{print substr($9, 1, length($9)-1)}')
add_metric "Free-RAM-cached-kernel" "pass" "${measurement}" "K"
measurement=$(echo "${line}" | awk '{print substr($13, 1, length($13)-1)}')
add_metric "Free-RAM-free" "pass" "${measurement}" "K"

# Detailed info on Used RAM.
line=$(grep "Used RAM:" "${logfile}")
measurement=$(echo "${line}" | awk '{print substr($5, 1, length($5)-1)}')
add_metric "Used-RAM-used-pss" "pass" "${measurement}" "K"
measurement=$(echo "${line}" | awk '{print substr($9, 1, length($9)-1)}')
add_metric "Used-RAM-kernel" "pass" "${measurement}" "K"
