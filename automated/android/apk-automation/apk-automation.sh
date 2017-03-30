#!/bin/sh
# shellcheck disable=SC1091

. ./../../lib/sh-test-lib
. ./../../lib/android-test-lib

SKIP_INSTALL="false"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
LOOPS="1"
TEST_NAME="linpack"
APK_DIR="./apks"

usage() {
    echo "Usage: $0 [-S <true|false>] [-s <serialno>] [-t <timeout>] [-l <loops>] [-n <test_name>] [-d <apk_dir>]" 1>&2
    exit 1
}

while getopts ":S:s:t:l:n:d:" opt; do
    case "${opt}" in
        S) SKIP_INSTALL="${OPTARG}" ;;
        s) ANDROID_SERIAL="${OPTARG}" ;;
        t) BOOT_TIMEOUT="${OPTARG}" ;;
        l) LOOPS="${OPTARG}" ;;
        n) TEST_NAME="${OPTARG}" ;;
        d) APK_DIR="${OPTARG}" ;;
        *) usage ;;
    esac
done

OUTPUT="$(pwd)/output/${TEST_NAME}"
export OUTPUT
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

! check_root && error_msg "Please run this script as superuser!"
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Package installation skipped"
else
    install_deps "adb git tar" "${SKIP_INSTALL}"
    git clone https://github.com/dtmilano/AndroidViewClient
    (
    cd AndroidViewClient/ || exit
    python setup.py install
    )
fi

initialize_adb
adb_root
wait_boot_completed "${BOOT_TIMEOUT}"

info_msg "device-${ANDROID_SERIAL}: About to run ${TEST_NAME}..."
python main.py -l "${LOOPS}" -n "${TEST_NAME}" -d "${APK_DIR}"

cp "${OUTPUT}/result.txt" "./output/"
