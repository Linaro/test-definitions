#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
LOGFILE="${OUTPUT}/kselftest.txt"
TESTPROG="kselftest_armhf.tar.gz"
KSELFTEST_PATH=/usr/lib/kselftests

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

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu) install_deps "sed wget xz-utils" "${SKIP_INSTALL}" ;;
        centOS|fedora) install_deps "sed wget xz" "${SKIP_INSTALL}" ;;
        unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

! check_root && error_msg "You need to be root to run this script."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"
cd "${OUTPUT}"

install

if [ -d "${KSELFTEST_PATH}" ]; then
    echo "kselftests found on rootfs"
    cd "${KSELFTEST_PATH}"
else
    # Download and extract kselftest tarball.
    wget http://testdata.validation.linaro.org/tests/kselftest/"${TESTPROG}" -O kselftest.tar.gz
    tar xf "kselftest.tar.gz"
    cd "kselftest"
fi

./run_kselftest.sh 2>&1 | tee "${LOGFILE}"
parse_output
