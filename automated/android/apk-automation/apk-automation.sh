#!/bin/bash -ex
# shellcheck disable=SC1091

. ./../../lib/sh-test-lib
. ./../../lib/android-test-lib

SKIP_INSTALL="true"
SET_GOVERNOR_POLICY=true
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
LOOPS="1"
TEST_NAME="linpack"
APK_DIR="./apks"
BASE_URL="http://testdata.validation.linaro.org/apks/"

usage() {
    echo "Usage: $0 [-S <true|false>] [-s <serialno>] [-t <timeout>] [-l <loops>] [-n <test_name>] [-d <apk_dir>] ['-u <base_url>'] [ -g <true|false>]" 1>&2
    exit 1
}

while getopts ":S:s:t:l:n:d:u:g:" opt; do
    case "${opt}" in
        S) SKIP_INSTALL="${OPTARG}" ;;
        s) ANDROID_SERIAL="${OPTARG}" ;;
        t) BOOT_TIMEOUT="${OPTARG}" ;;
        l) LOOPS="${OPTARG}" ;;
        n) TEST_NAME="${OPTARG}" ;;
        d) APK_DIR="${OPTARG}" ;;
        u) BASE_URL="${OPTARG}" ;;
        g) SET_GOVERNOR_POLICY="${OPTARG}" ;;
        *) usage ;;
    esac
done

OUTPUT="$(pwd)/output/${TEST_NAME}"
export OUTPUT
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Package installation skipped"
else
    ! check_root && error_msg "Please run this script as superuser!"
    #install_deps "git python python-lxml python-pil python-setuptools python-requests python-matplotlib python-requests ca-certificates curl tar xz-utils" "${SKIP_INSTALL}"
    install_deps "python3-distutils git ca-certificates curl tar xz-utils" "${SKIP_INSTALL}"
    if python3 --version|grep 'Python 3.6'; then
        # Workaround for Ubuntu 18.04 Bionic version.
        # ModuleNotFoundError: No module named 'distutils.cmd' needs python3-distutils
        url_pip="https://bootstrap.pypa.io/pip/3.6/get-pip.py"
        url_android_view_clien="https://github.com/liuyq/AndroidViewClient.git"
    else
        url_pip="https://bootstrap.pypa.io/get-pip.py"
        url_android_view_clien="https://github.com/dtmilano/AndroidViewClient"
    fi

    curl "${url_pip}" -o get-pip.py
    sudo python3 get-pip.py
    sudo pip install virtualenv
    pip --version
    virenv_dir=python-workspace
    virtualenv --python=python3 ${virenv_dir}
    [ ! -d AndroidViewClient ]  && git clone --depth 1 "${url_android_view_clien}"
    # shellcheck disable=SC1090
    source ${virenv_dir}/bin/activate

    (
    cd AndroidViewClient/ || exit
    python3 setup.py install
    )
fi

initialize_adb
adb_root
wait_boot_completed "${BOOT_TIMEOUT}"
disable_suspend

info_msg "device-${ANDROID_SERIAL}: About to run ${TEST_NAME}..."
option_g="-g"
if [ -n "${SET_GOVERNOR_POLICY}" ] && [ "X${SET_GOVERNOR_POLICY}" = "Xfalse" ]; then
    option_g=""
fi
python3 main.py -l "${LOOPS}" -n "${TEST_NAME}" -d "${APK_DIR}" -u "${BASE_URL}" ${option_g}
