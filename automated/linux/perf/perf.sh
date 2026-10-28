#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
RESULT_LOG="${OUTPUT}/result_log.txt"
export RESULT_FILE
SKIP_INSTALL="false"
PARALLEL_TESTS="false"
TESTPROG_URL=""
# List of test cases
TEST="record report stat test"
# PERF version
PERF_VERSION="$(uname -r | cut -d . -f 1-2)"

usage() {
    echo "Usage: $0 [options...]" 1>&2
    echo " [-s <true|false>]        Skip dependency installation" 1>&2
    echo " [-p <true|false>]        Run tests in parallel" 1>&2
    echo " [-u <url>]               Download an installed perf tar archive" 1>&2
    exit 1
}

while getopts "s:p:u:h" arg; do
   case "$arg" in
     s) SKIP_INSTALL="${OPTARG}";;
     p) PARALLEL_TESTS="${OPTARG}";;
     u) TESTPROG_URL="${OPTARG}";;
     h|*) usage ;;
   esac
done

# Keep a prebuilt perf and its support files together without replacing the
# rootfs's installed perf or OpenCSD libraries.
setup_prebuilt_perf() {
    PERF_ROOT=$(mktemp -d "${OUTPUT}/perf-binaries.XXXXXX") || return
    wget -O "${PERF_ROOT}.tar" "${TESTPROG_URL}" || return
    tar -xf "${PERF_ROOT}.tar" -C "${PERF_ROOT}" || return
    rm -f "${PERF_ROOT}.tar"
    test -x "${PERF_ROOT}/usr/bin/perf" || return
    test -d "${PERF_ROOT}/usr/libexec/perf-core" || return

    PATH="${PERF_ROOT}/usr/bin:${PATH}"
    PERF_EXEC_PATH="${PERF_ROOT}/usr/libexec/perf-core"
    export PATH PERF_EXEC_PATH
    for perf_libdir in "${PERF_ROOT}/usr/lib/"*; do
        if [ -d "${perf_libdir}" ]; then
            LD_LIBRARY_PATH="${perf_libdir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        fi
    done
    export LD_LIBRARY_PATH
    return 0
}

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
    set -- -v
    if [ "${PARALLEL_TESTS}" != "true" ]; then
        set -- -S "$@"
    fi
    # Keep live output without losing perf's status to tee in this POSIX shell.
    perf_test_exit="${OUTPUT}/perf-test.exit"
    {
        perf test "$@"
        echo "$?" > "${perf_test_exit}"
    } 2>&1 | tee "${RESULT_LOG}"
    if [ "$(cat "${perf_test_exit}")" = "0" ]; then
        report_pass "perf_test"
    else
        report_fail "perf_test"
    fi
    rm -f "${perf_test_exit}"
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
    info_msg "dependency installation skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        if [ -n "${TESTPROG_URL}" ]; then
            # libdw1/libelf1 are also provided by the Debian t64 packages.
            pkgs="wget tar xz-utils python3 libelf1 libdw1 libnuma1"
            pkgs="${pkgs} libtraceevent1 liblzma5 libzstd1 zlib1g libstdc++6"
        else
            pkgs="python3 linux-perf-${PERF_VERSION}"
        fi
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *)
        warn_msg "Unsupported distribution: package install skipped"
    esac
fi

if [ -n "${TESTPROG_URL}" ]; then
    setup_prebuilt_perf
    exit_on_fail "perf-bundle-setup"
fi

command -v python3 > /dev/null
exit_on_fail "perf-parser-check"
info_msg "check which perf"
which perf > /dev/null
exit_on_fail "perf-existence-check"
perf version --build-options
exit_on_fail "perf-runtime-check"

# List of test cases "record report stat test"
for tests in ${TEST}; do
    run_perf_"${tests}"
done
