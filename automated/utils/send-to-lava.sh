#!/bin/sh

RESULT_FILE="$1"

while read line; do
    if echo "${line}" | egrep -q ".* +(pass|fail|skip)$"; then
        test="$(echo "${line}" | awk '{print $1}')"
        result="$(echo "${line}" | awk '{print $2}')"
        lava-test-case "${test}" --result "${result}"
    elif echo "${line}" | egrep -q ".* +(pass|fail|skip) +[0-9.E-]+ [A-Za-z./]+$"; then
        test="$(echo "${line}" | awk '{print $1}')"
        result="$(echo "${line}" | awk '{print $2}')"
        measurement="$(echo "${line}" | awk '{print $3}')"
        units="$(echo "${line}" | awk '{print $4}')"
        lava-test-case "${test}" --result "${result}" --measurement "${measurement}" --units "${units}"
    fi
done < "${RESULT_FILE}"
