#!/bin/sh

RESULT_FILE="$1"

which lava-test-case > /dev/null 2>&1
lava_test_case="$?"
which lava-test-set > /dev/null 2>&1
lava_test_set="$?"

if [ -f "${RESULT_FILE}" ]; then
    while read -r line; do
        if echo "${line}" | grep -iq -E ".* +(pass|fail|skip|unknown)$"; then
            test="$(echo "${line}" | awk '{print $1}')"
            result="$(echo "${line}" | awk '{print $2}')"

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
                    echo "<LAVA_SIGNAL_TESTSET START ${test_set_name}>"
                else
                    echo "<LAVA_SIGNAL_TESTSET STOP>"
                fi
            fi
        fi
    done < "${RESULT_FILE}"
else
    echo "WARNING: result file is missing!"
fi
