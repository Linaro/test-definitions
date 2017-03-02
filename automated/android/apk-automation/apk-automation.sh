#!/bin/sh -e
# shellcheck disable=SC1091
. ../../lib/sh-test-lib
. ../../lib/android-test-lib

SKIP_INSTALL="false"
SN=""
TIMEOUT="300"
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export  RESULT_FILE

TEST_NAME="linpack"
LOOP_COUNT="1"
COLLECT_STREAMLINE="false"
VERBOSE_OUTPUT="FALSE"
RECORD_STATISTICS="TRUE"
RECORD_CSV="TRUE"

usage() {
    echo "Usage: $0 [-s <true|false>] [-n <serialno>] [-o <timeout>] [-t <test_name>] [-l <loop_count>] [-m <true|false>] [-v <TRUE|FALSE>] [-r <TRUE|FALSE>] [-c <TRUE|FALSE>]" 1>&2
    exit 1
}

while getopts ":s:n:o:t:l:m:v:r:c:" opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        n) SN="${OPTARG}" ;;
        o) TIMEOUT="${OPTARG}" ;;
        t) TEST_NAME="${OPTARG}" ;;
        l) LOOP_COUNT="${OPTARG}" ;;
        m) COLLECT_STREAMLINE="${OPTARG}" ;;
        v) VERBOSE_OUTPUT="${OPTARG}" ;;
        r) RECORD_STATISTICS="${OPTARG}" ;;
        c) RECORD_CSV="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as superuser!"
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Package installation skipped"
else
    install_deps "bc curl wget zip git python-lxml python-pil python-setuptools" "${SKIP_INSTALL}"
    git clone https://github.com/dtmilano/AndroidViewClient
    (
    cd AndroidViewClient/ || error_msg "DIR AndroidViewClient not exists"
    python setup.py install
    )
    install_latest_adb
fi

initialize_adb
adb_root
wait_boot_completed "${TIMEOUT}"
create_out_dir "${OUTPUT}"

./"${TEST_NAME}"/execute.sh --serial "${SN}" --loop-count "${LOOP_COUNT}" --streamline "${COLLECT_STREAMLINE}" --verbose-output "${VERBOSE_OUTPUT}" --record-statistics "${RECORD_STATISTICS}" --record-csv "${RECORD_CSV}" || true
