#!/bin/sh -ex

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

create_out_dir "${OUTPUT}"

initialize_adb
adb_root
wait_boot_completed "300"

parser() {
    logfile="$1"
    case "$2" in
        stringbench) prefix="32bit" ;;
        stringbench64) prefix="64bit" ;;
    esac

    while read -r line; do
        test_case_id=$(echo "${line}" | cut -d: -f1 | tr -c '[:alnum:]:.' '_' | tr -s '_' | sed 's/_$//')
        test_case_id="${prefix}_${test_case_id}"
        measurement=$(echo "${line}" | awk '{print $(NF-1)}')
        units=$(echo "${line}" | awk '{print $NF}')
        add_metric "${test_case_id}" "pass" "${measurement}" "${units}"
    done < "${logfile}"
}

for test in stringbench stringbench64; do
    info_msg "device-${SN}: About to run ${test}"
    if test -n "$(adb -s "${SN}" shell "which ${test}")"; then
        adb -s "${SN}" shell "${test}" | tee "${OUTPUT}/${test}.log"
    else
        warn_msg "${test} command NOT found"
        report_fail "${test}-existence-check"
        exit 0
    fi
    parser "${OUTPUT}/${test}.log" "${test}"
done
