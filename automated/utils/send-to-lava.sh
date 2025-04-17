#!/bin/sh

RESULT_FILE="$1"
RESULT_DIR="$2"
if [ -z "${RESULT_DIR}" ]; then
    RESULT_DIR="$(dirname "${RESULT_FILE}")"
fi

signal() {
    if [ -z ${KMSG} ]
    then
        echo "${1}"
    else
        echo "<0>${1}" > /dev/kmsg
    fi
}

show_output() {
    test_name="$1"
    test_output="${RESULT_DIR}/${test_name}.log"
    if [ -r "$test_output" ]; then
        signal "<LAVA_SIGNAL_STARTTC $test_name>"
        cat "$test_output"
        signal "<LAVA_SIGNAL_ENDTC $test_name>"
    fi
}

command -v lava-test-case > /dev/null 2>&1
lava_test_case="$?"
command -v lava-test-set > /dev/null 2>&1
lava_test_set="$?"

if [ -f "${RESULT_FILE}" ]; then
    while read -r line; do
        if echo "${line}" | grep -iq -E ".* +(pass|fail|skip|unknown)$"; then
            test="${line%% *}"
            result="${line##* }"

            show_output "${test}"
            if [ "${lava_test_case}" -eq 0 ]; then
                lava-test-case "${test}" --result "${result}"
            else
                echo "<TEST_CASE_ID=${test} RESULT=${result}>"
            fi
        elif echo "${line}" | grep -iq -E ".*+ (pass|fail|skip|unknown)+ .*+"; then
            test="$(echo "${line}" | awk '{print $1}')"
            result="$(echo "${line}" | awk '{print $2}')"
            measurement="$(echo "${line}" | awk '{print $3}')"
            units="$(echo "${line}" | awk '{print $4}')"

            show_output "${test}"
            if [ "${lava_test_case}" -eq 0 ]; then
                if [ -n "${units}" ]; then
                    lava-test-case "${test}" --result "${result}" --measurement "${measurement}" --units "${units}"
                else
                    lava-test-case "${test}" --result "${result}" --measurement "${measurement}"
                fi
            else
               echo "<TEST_CASE_ID=${test} RESULT=${result} MEASUREMENT=${measurement} UNITS=${units}>"
            fi
        elif echo "${line}" | grep -iq -E "^lava-test-set.*"; then
            test_set_status="$(echo "${line}" | awk '{print $2}')"
            test_set_name="$(echo "${line}" | awk '{print $3}')"
            if [ "${lava_test_set}" -eq 0 ]; then
                lava-test-set "${test_set_status}" "${test_set_name}"
            else
                if [ "${test_set_status}" = "start" ]; then
                    signal "<LAVA_SIGNAL_TESTSET START ${test_set_name}>"
                else
                    signal "<LAVA_SIGNAL_TESTSET STOP>"
                fi
            fi
        fi
    done < "${RESULT_FILE}"
else
    echo "WARNING: result file is missing!"
fi
