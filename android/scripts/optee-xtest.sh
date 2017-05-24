#!/system/bin/sh
#
# Run OP-TEE sanity test suite.
#
# Copyright (C) 2010 - 2016, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>

LEVEL="$1"
TEST_SUITE="$2"

pass_fail_parser() {
    local field="$1"
    # Collect test case ID and case name, then join them with minus.
    grep "^\* ${TEST_SUITE}" "${TEST_SUITE}"_output.txt \
        | cut -d "_" -f"${field}"- \
        | sed 's/ /-/g' > "${TEST_SUITE}"_case_list.txt

    # Get test result for each test case, update result file and send to LAVA.
    rm -f "${TEST_SUITE}"_result.txt
    while read line; do
        test_id=$(echo "${line}" | awk -F'-' '{ print $1 }')
        test_case="${line}"
        test_result=$(grep -m 1 "^${TEST_SUITE}.*${test_id} [OK|FAILED]" \
            "${TEST_SUITE}"_output.txt | awk '{ print $2 }')

        if [ "${test_result}" = "OK" ]; then
            echo "${test_case} pass" >> "${TEST_SUITE}"_result.txt
            lava-test-case "${test_case}" --result "pass"
        else
            echo "${test_case} fail" >> "${TEST_SUITE}"_result.txt
            lava-test-case "${test_case}" --result "fail"
        fi
    done < "${TEST_SUITE}"_case_list.txt

    rm -f "${TEST_SUITE}"_case_list.txt
}

benchmark_parser() {
    while read line; do
        test_id=$(echo "${line}" | awk -F'-' '{ print $1 }')
        test_case=$(echo "${line}" | awk '{ print $1 }')
        test_result=$(echo "${line}" | awk '{ print $2 }')
        sed -n "/^\* ${TEST_SUITE}.*_${test_id}/,/${TEST_SUITE}.*_${test_id} [OK|FAILED]/p" \
            "${TEST_SUITE}"_output.txt > "${test_id}"_benchmark_raw.txt

        grep "[0-9].*|" "${test_id}"_benchmark_raw.txt \
            | awk -v test_case="${test_case}" '{data_size=$1; speed=$NF; \
            print test_case"-"data_size" "speed; }' \
            > "${test_id}"_benchmark.txt
        rm -f "${test_id}"_benchmark_raw.txt

        while read line; do
            test_case=$(echo "${line}" | awk '{ print $1 }')
            test_measurement=$(echo "${line}" | awk '{ print $2 }')
                lava-test-case "${test_case}" --result "${test_result}" \
                --measurement "${test_measurement}" --units "kB/s"
        done < "${test_id}"_benchmark.txt
    done < "${TEST_SUITE}"_result.txt
}

stats_parser() {
    for i in "subtests" "test cases"; do
        stats=$(egrep "^[0-9]+ $i of which [0-9]+ failed" \
            "${TEST_SUITE}"_output.txt)
        total=$(echo "${stats}" | awk '{print $1}')
        fails=$(echo "${stats}" | awk '{print $(NF-1)}')
        passes=$(( total - fails ))

        test "$i" = "test cases" && i="tests"
        lava-test-case "xtest-$i-fails" --result "pass" \
            --measurement "${fails}" --units "tests"
        lava-test-case "xtest-$i-passes" --result "pass" \
            --measurement "${passes}" --units "tests"
        lava-test-case "xtest-$i-fail-rate" --result "pass" \
            --measurement "${fails}"/"${total}" --units "percent"
    done

    skip=$(egrep "^[0-9]+ test case was skipped" \
        "${TEST_SUITE}"_output.txt | awk '{print $1}')
    lava-test-case xtest-tests-skipped --result "pass" \
        --measurement "${skip}" --units "tests"

}

# Run xtest
xtest -l "${LEVEL}" -t "${TEST_SUITE}" 2>&1 | tee "${TEST_SUITE}"_output.txt
if [ $? -eq 0 ]; then
    lava-test-case "optee-xtest-run" --result "pass"
else
    lava-test-case "optee-xtest-run" --result "fail"
fi

# Parse test result.
stats_parser
if [ "${TEST_SUITE}" = "regression" ]; then
    pass_fail_parser 3
elif [ "${TEST_SUITE}" = "benchmark" ]; then
    pass_fail_parser 4
    benchmark_parser
fi
