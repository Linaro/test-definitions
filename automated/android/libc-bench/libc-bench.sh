#!/bin/sh -e

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
LOOPS="1"

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-l <loops>]" 1>&2
    exit 1
}

while getopts ":s:t:l:" o; do
  case "$o" in
    # Specify device serial number when more than one device connected.
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    l) LOOPS="${OPTARG}" ;;
    *) usage ;;
  esac
done

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"

parse_log() {
    case "${test}" in
        libcbench) prefix="32bit" ;;
        libcbench64) prefix="64bit" ;;
    esac

    while read -r line; do
        # Parse test case id line.
        if echo "${line}" | grep -q "^b_"; then
            tc="${prefix}_$(echo "${line}" | tr -c '[:alnum:]' '_' | tr -s '_' | sed 's/_$//')"
        fi

        # Parse the following value line.
        if echo "${line}" | grep -q '^time:'; then
            time=$(echo "${line}" | awk '{print $2}' | sed 's/,//')
            add_metric "${tc}_time" "pass" "${time}" "seconds"

            virt=$(echo "${line}" | awk '{print $4}'| sed 's/,//')
            add_metric "${tc}_virt" "pass" "${virt}" "KB"

            res=$(echo "${line}" | awk '{print $6}'| sed 's/,//')
            add_metric "${tc}_res" "pass" "${res}" "KB"

            dirty=$(echo "${line}" | awk '{print $8}')
            add_metric "${tc}_dirty" "pass" "${dirty}" "KB"
        fi
    done < "${logfile}"
}

if ! adb_shell_which "libcbench" && ! adb_shell_which "libcbench64"; then
    report_fail "check_cmd_existence"
    exit 1
fi

for test in libcbench libcbench64; do
    if ! adb_shell_which "${test}"; then
        continue
    fi

    info_msg "device-${ANDROID_SERIAL}: About to run ${test}..."
    for i in $(seq "${LOOPS}"); do
        info_msg "Running iteration [${i}/${LOOPS}]..."
        logfile="${OUTPUT}/${test}-$i.log"
        adb shell "${test}" | tee "${logfile}"
        parse_log
    done
done

# Calculate min, mean and max for 'time' metric.
if [ "${LOOPS}" -gt 2 ]; then
    tc_list=$(awk '{print $1}' "${RESULT_FILE}" | grep "time" | sort -u)
    for tc in ${tc_list}; do
        grep "$tc" "${RESULT_FILE}" \
            | awk -v tc="${tc}" \
                  '{
                       if(min=="") {min=max=$3};
                       if($3>max) {max=$3};
                       if($3< min) {min=$3};
                       total+=$3; count+=1;
                   }
               END {
                       printf("%s-min pass %s %s\n", tc, min, $4);
                       printf("%s-mean pass %s %s\n", tc, total/count, $4);
                       printf("%s-max pass %s %s\n", tc, max, $4)
                   }' \
            | tee -a "${RESULT_FILE}"
    done
fi
