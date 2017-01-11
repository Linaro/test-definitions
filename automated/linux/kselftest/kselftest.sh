#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
LOGFILE="${OUTPUT}/kselftest.txt"
TESTPROG="kselftest_armhf.tar.gz"

usage() {
    echo "Usage: $0 [-t kselftest_aarch64.tar.gz | kselftest_armhf.tar.gz] [-s true|false]" 1>&2
    exit 1
}

while getopts "t:s:h" opt; do
    case "${opt}" in
        t) TESTPROG="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

parse_output() {
    grep "selftests:" "${LOGFILE}"  2>&1 | tee -a "${RESULT_FILE}"
    sed -i -e 's/: /-/g' "${RESULT_FILE}"
    sed -i -e 's/\[//g' "${RESULT_FILE}"
    sed -i -e 's/]//g' "${RESULT_FILE}"
}

dist_name
# shellcheck disable=SC2154
case "${dist}" in
    Debian|Ubuntu) pkgs="sed wget xz-utils" ;;
    CentOS|Fedora) pkgs="sed wget xz" ;;
esac
! check_root && error_msg "You need to be root to run testing!"
install_deps "${pkgs}" "${SKIP_INSTALL}"

[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"
cd "${OUTPUT}"

# Download and extract kselftest tarball.
wget http://testdata.validation.linaro.org/tests/kselftest/"${TESTPROG}" -O kselftest.tar.gz

tar xf "kselftest.tar.gz"
cd "kselftest"

./run_kselftest.sh 2>&1 | tee "${LOGFILE}"
parse_output
