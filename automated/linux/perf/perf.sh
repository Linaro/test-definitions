#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
export RESULT_FILE
SKIP_INSTALL="false"
PARALLEL_TESTS="false"
# List of test cases
TEST="record report stat test"
# PERF version
PERF_VERSION="$(uname -r | cut -d . -f 1-2)"

usage() {
    echo "Usage: $0 [options...]" 1>&2
    echo " [-s <true|false>]        Skip to install perf" 1>&2
    echo " [-p <true|false>]        Run tests in parallel" 1>&2
    exit 1
}

while getopts "s:p:h" arg; do
   case "$arg" in
     s) SKIP_INSTALL="${OPTARG}";;
     p) PARALLEL_TESTS="${OPTARG}";;
     h|*) usage ;;
   esac
done

# Run perf record tests
run_perf_record() {
    # Test 'perf record'
    info_msg "Performing perf record test..."
    TCID="perf_record_test"
    perf record -e cycles -o perf-lava-test.data ls -a  2>&1 | tee perf-record.log
    samples=$(grep -ao "[0-9]\\+[ ]\\+samples" perf-record.log| cut -f 1 -d' ')
    if [ "${samples}" -gt 1 ]; then
        report_pass "${TCID}"
    else
        report_fail "${TCID}"
    fi
    rm perf-record.log
}

# Run perf report tests
run_perf_report() {
    # Test 'perf report'
    info_msg "Performing perf report test..."
    TCID="perf_report_test"
    perf report -i perf-lava-test.data 2>&1 | tee perf-report.log
    pcnt_samples=$(grep -c -e "^[ ]\\+[0-9]\\+.[0-9]\\+%" perf-report.log)
    if [ "${pcnt_samples}" -gt 1 ]; then
        report_pass "${TCID}"
    else
        report_fail "${TCID}"
    fi
    rm perf-report.log perf-lava-test.data
}

# Run perf stat tests
run_perf_stat() {
    # Test 'perf stat'
    info_msg "Performing perf stat test..."
    TCID="perf_stat_test"
    perf stat -e cycles ls -a 2>&1 | tee perf-stat.log
    cycles=$(grep -o "[0-9,]\\+[ ]\\+cycles" perf-stat.log | sed 's/,//g' | cut -f 1 -d' ')
    if [ -z "${cycles}" ]; then
        report_skip "${TCID}"
    else
        if [ "${cycles}" -gt 1 ]; then
            report_pass "${TCID}"
        else
            report_fail "${TCID}"
        fi
    fi
    rm perf-stat.log
}

# Run perf test tests
run_perf_test() {
    # Test 'perf test'
    info_msg "Performing 'perf test'..."
    if [ "${PARALLEL_TESTS}" = "true" ]; then
        perf test -v 2>&1 | tee "${RESULT_LOG}"
    else
        perf test -S -v 2>&1 | tee "${RESULT_LOG}"
    fi
    report_pass "perf_test"
    parse_perf_test_results
}

# Parse perf test results
parse_perf_test_results() {
    ./parse-output.py < "${RESULT_LOG}" | tee -a "${RESULT_FILE}"

    # Clean up
    rm -rf "${RESULT_LOG}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run perf test..."
info_msg "Output directory: ${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install perf skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
	pkgs="linux-perf-${PERF_VERSION}"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *)
        warn_msg "Unsupported distribution: package install skipped"
    esac
fi

info_msg "check which perf"
which perf > /dev/null
exit_on_fail "perf-existence-check"

# List of test cases "record report stat test"
for tests in ${TEST}; do
    run_perf_"${tests}"
done
