#!/bin/sh -ex
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
SKIP_INSTALL="false"
AEP_REPOSITORY="https://git.linaro.org/tools/arm-probe.git"
AEP_REF="master"

usage() {
    echo "Usage: $0 [-t <aep_repository_ref>] [-r <aep_repository>]" 1>&2
    exit 1
}

while getopts ":t:r:" opt; do
    case "${opt}" in
        t) AEP_REF="${OPTARG}" ;;
        r) AEP_REPOSITORY="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this test as root."
cd "${TEST_DIR}"
create_out_dir "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Dependency installation skipped"
else
    PKGS="git autoconf libtool cmake zlib1g-dev libssl-dev python"
    install_deps "${PKGS}"
fi
git clone "${AEP_REPOSITORY}" arm-probe
cd arm-probe
git checkout "${AEP_REF}"
./autogen.sh
./configure --prefix=/usr
make
make install
report_pass "AEP installed"
