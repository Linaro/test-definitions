#!/bin/sh -ex
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
SKIP_INSTALL="false"
AEP_CONFIG_REPOSITORY="https://git.linaro.org/power/energy-probe-ext.git"
AEP_CONFIG_REF="master"
AEP_CONFIG_TARGET_PATH="/root/energy-probe-ext"

usage() {
    echo "Usage: $0 [-t <aep_config_repository_ref>] [-r <aep_config_repository>] [-p <aep_config_target_path>]" 1>&2
    exit 1
}

while getopts ":t:r:p:" opt; do
    case "${opt}" in
        t) AEP_CONFIG_REF="${OPTARG}" ;;
        r) AEP_CONFIG_REPOSITORY="${OPTARG}" ;;
        p) AEP_CONFIG_TARGET_PATH="${OPTARG}" ;;
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
    PKGS="git"
    install_deps "${PKGS}"
fi
create_out_dir "${AEP_CONFIG_TARGET_PATH}"
git clone "${AEP_CONFIG_REPOSITORY}" energy-probe-ext
cd energy-probe-ext
git checkout "${AEP_CONFIG_REF}"
cp -r ./* "${AEP_CONFIG_TARGET_PATH}"
report_pass "AEP config installed"
