#!/bin/sh

RESULT_FILE="$1"

which lava-test-case
lava_test_case="$?"

if [ -f "${RESULT_FILE}" ]; then
    while read line; do
        if echo "${line}" | egrep -iq ".* +(pass|fail|skip)$"; then
            test="$(echo "${line}" | awk '{print $1}')"
            result="$(echo "${line}" | awk '{print $2}')"

            if [ "${lava_test_case}" -eq 0 ]; then
                lava-test-case "${test}" --result "${result}"
            else
                echo "<TEST_CASE_ID=${test} RESULT=${result}>"
            fi
        elif echo "${line}" | egrep -iq ".* +(pass|fail|skip) +[0-9.E-]+ [A-Za-z./]+$"; then
            test="$(echo "${line}" | awk '{print $1}')"
            result="$(echo "${line}" | awk '{print $2}')"
            measurement="$(echo "${line}" | awk '{print $3}')"
            units="$(echo "${line}" | awk '{print $4}')"

            if [ "${lava_test_case}" -eq 0 ]; then
                lava-test-case "${test}" --result "${result}" --measurement "${measurement}" --units "${units}"
            else
               echo "<TEST_CASE_ID=${test} RESULT=${result} UNITS=${units} MEASUREMENT=${measurement}>"
            fi
        fi
    done < "${RESULT_FILE}"
else
    echo "WARNING: result file is missing!"
fi
