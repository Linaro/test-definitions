#!/bin/bash

set -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
GRP_RESULT_FILE="${OUTPUT}/grp_result.txt"
GRP_OUTPUT_FILE="${OUTPUT}/grp_output.txt"
# Absolute path to this script. /home/user/bin/foo.sh
SCRIPT="$(readlink -f "${0}")"
# Absolute path this script is in. /home/user/bin
SCRIPTPATH="$(dirname "${SCRIPT}")"
echo "Script path is: ${SCRIPTPATH}"
SKIP_INSTALL="true"
# List of test cases
TEST="conformance functional stress"
# LTP version
LTP_VERSION="20260930"

LTP_PRE_INSTALL=/opt/ltp
LTP_PATH=/opt/ltp/testcases/open_posix_testsuite

while getopts "s:v:t:" arg; do
   case "$arg" in
     s) SKIP_INSTALL="${OPTARG}";;
     v) LTP_VERSION="${OPTARG}";;
     t) GRP_TEST="${OPTARG}";;
     *) ;;
   esac
done

# Install LTP open posix test suite
install_ltp_open_posix() {
    rm -rf "${LTP_PRE_INSTALL}"
    mkdir -p "${LTP_PRE_INSTALL}"
    # shellcheck disable=SC2164
    cd "${LTP_PRE_INSTALL}"
    # shellcheck disable=SC2140
    wget https://github.com/linux-test-project/ltp/releases/download/"${LTP_VERSION}"/ltp-full-"${LTP_VERSION}".tar.xz
    tar --strip-components=1 -Jxf ltp-full-"${LTP_VERSION}".tar.xz
    ./configure --with-open-posix-testsuite
    # shellcheck disable=SC2164
    cd "${LTP_PATH}"
    make generate-makefiles || true

    for EACH_TEST in ${TEST}
    do
      make "${EACH_TEST}"-all || true
    done
}

# Parse LTP open posix output
parse_ltp_output() {
    for EACH_TEST in ${TEST}
    do
      sed -i -e "s/\// /g" logfile."${EACH_TEST}"-test
      grep -E ": PASS"  logfile."${EACH_TEST}"-test \
         | awk '{print $(NF-2)" "$(NF)}' \
         | sed 's/://g; s/PASS/pass/'  >> "${RESULT_FILE}"
      grep -E ": FAILED|: SKIPPED|: UNSUPPORTED|: UNTESTED|: UNRESOLVED|: HUNG"  logfile."${EACH_TEST}"-test \
         | awk '{print $(NF-3)" "$(NF-1)}' \
         | sed 's/://g; s/FAILED/fail/; s/SKIPPED/skip/; s/UNSUPPORTED/skip/; s/UNTESTED/skip/; s/UNRESOLVED/fail/; s/HUNG/skip/'  >> "${RESULT_FILE}"
    done

}

# Parse LTP open posix grp output
parse_ltp_grp_output() {
    sed -i.bak '/^\(PASS\|FAIL\|TOTAL\|Testing\)[[:space:]]/!d' "${GRP_OUTPUT_FILE}"
    paste -d " " - - - - < "${GRP_OUTPUT_FILE}" | tee "${GRP_RESULT_FILE}"
    sed -i 's/\s\s*/ /g' "${GRP_RESULT_FILE}"
    sed -i 's/Testing //g' "${GRP_RESULT_FILE}"
    awk '
        NF != 7 || $2 != "PASS" || $4 != "FAIL" || $6 != "TOTAL" ||
        $3 !~ /^[0-9]+$/ || $5 !~ /^[0-9]+$/ || $7 !~ /^[0-9]+$/ ||
        $7 == 0 || $3 + $5 != $7 { exit 1 }
        END { if (NR == 0) exit 1 }
    ' "${GRP_RESULT_FILE}" || error_msg "Missing or incomplete Open POSIX summary"
    {
    sed 's/PASS/pass/; s/FAIL/fail/; s/CONF/skip/' "${GRP_RESULT_FILE}" | awk '{ if($5 > 0) {print $1 " " $4} else {print $1 " " $2} }'
    grep -e "UNRESOLVED" -e "UNTESTED" -e "UNSUPPORTED" -e "HUNG" -e "SKIPPED" "${GRP_OUTPUT_FILE}.bak" \
	    | awk -F':' '{print $1 $3}' \
	    | tr '/' '.' \
	    | sed 's/SKIPPED/skip/; s/UNSUPPORTED/fail/; s/UNTESTED/fail/; s/UNRESOLVED/fail/; s/HUNG/skip/'
    } >> "${RESULT_FILE}"
}

# Run LTP test suite
run_ltp_open_posix() {
    if [ ! -f "${LTP_PATH}/Makefile" ]; then
        : > "${GRP_OUTPUT_FILE}" || error_msg "Cannot create Open POSIX output file"
        runner_count=0
        for test_group in ${TEST}; do
            [ -d "${LTP_PATH}/${test_group}" ] \
                || error_msg "Cannot find installed Open POSIX ${test_group} tests"
            previous_runner_count=${runner_count}
            run_ltp_open_posix_installed "${LTP_PATH}/${test_group}"
            [ "${runner_count}" -gt "${previous_runner_count}" ] \
                || error_msg "No installed Open POSIX ${test_group} runners found"
            [ "$(grep -c '^Testing ' "${GRP_OUTPUT_FILE}")" -eq "${runner_count}" ] \
                || error_msg "Open POSIX ${test_group} runner produced no summary"
        done
        parse_ltp_grp_output
        return
    fi

    # shellcheck disable=SC2164
    cd "${LTP_PATH}"
    for EACH_TEST in ${TEST}
    do
      make "${EACH_TEST}"-test || true
    done
    parse_ltp_output
}

run_ltp_open_posix_installed() {
    local -a runner_status

    if [ -f "$1/run.sh" ]; then
        [ -x "$1/run.sh" ] || error_msg "Open POSIX runner is not executable: $1/run.sh"
        test_name=$(printf '%s\n' "${1#"${LTP_PATH}"/}" | tr '/' '.')
        (cd "$1" && ./run.sh) 2>&1 \
            | sed "s|^Testing .*|Testing ${test_name}|" \
            | tee -a "${GRP_OUTPUT_FILE}"
        runner_status=("${PIPESTATUS[@]}")
        [ "${runner_status[1]}" -eq 0 ] && [ "${runner_status[2]}" -eq 0 ] \
            || error_msg "Cannot save Open POSIX output"
        runner_count=$((runner_count + 1))
    else
        for test_directory in "$1"/*; do
            [ -d "${test_directory}" ] && [ ! -L "${test_directory}" ] || continue
            run_ltp_open_posix_installed "${test_directory}"
        done
    fi
}

# Run specific LTP open posix group tests
run_ltp_open_posix_grp() {
    local group_runner="${LTP_PRE_INSTALL}/bin/run-posix-option-group-test.sh"
    local -a runner_status

    GRP_TEST=$1
    [ -x "${group_runner}" ] \
        || error_msg "Open POSIX group runner is not executable: ${group_runner}"
    "${group_runner}" "${GRP_TEST}" 2>&1 | tee "${GRP_OUTPUT_FILE}"
    runner_status=("${PIPESTATUS[@]}")
    [ "${runner_status[1]}" -eq 0 ] || error_msg "Cannot save Open POSIX output"
    [ "${runner_status[0]}" -eq 0 ] \
        || error_msg "Open POSIX group runner failed with exit status ${runner_status[0]}"
    parse_ltp_grp_output
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run ltp test..."
info_msg "Output directory: ${OUTPUT}"

if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    info_msg "install-ltp-open-posix skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="xz-utils flex bison build-essential wget curl net-tools sudo libaio-dev expect automake acl"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      centos|fedora)
        pkgs="xz flex bison make automake gcc gcc-c++ kernel-devel wget curl net-tools sudo libaio expect acl"
        install_deps "${pkgs}" "${SKIP_INSTALL}"
        ;;
      *)
        warn_msg "Unsupported distribution: package install skipped"
    esac

    info_msg "Run install-ltp-open-posix"
    install_ltp_open_posix
fi
info_msg "Running run-ltp-open-posix"

if [ "${GRP_TEST}" != "" ]; then
    run_ltp_open_posix_grp "${GRP_TEST}"
else
    run_ltp_open_posix
fi
