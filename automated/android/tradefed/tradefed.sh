#!/bin/sh -x

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

export PATH=$PWD/platform-tools:$PATH
TIMEOUT="300"
PKG_DEPS="curl wget zip xz-utils python-lxml python-setuptools python-pexpect aapt android-tools-adb lib32z1-dev libc6-dev-i386 lib32gcc1 libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 libncurses5:i386"
TEST_URL="http://testdata.validation.linaro.org/cts/android-cts-7.1_r1.zip"
TEST_PARAMS="run cts -m CtsBionicTestCases --abi arm64-v8a --disable-reboot --skip-preconditions --skip-device-info"
TEST_PATH="android-cts"
RESULT_FILE="$(pwd)/output/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-o timeout] [-n serialno] [-c cts_url] [-t test_params] [-p test_path]" 1>&2
    exit 1
}

while getopts ':o:n:d:c:t:p:' opt; do
    case "${opt}" in
        o) TIMEOUT="${OPTARG}" ;;
        n) ANDROID_SERIAL="${OPTARG}" ;;
        c) TEST_URL="${OPTARG}" ;;
        t) TEST_PARAMS="${OPTARG}" ;;
        p) TEST_PATH="${OPTARG}" ;;
        u) ;;
        *) usage ;;
    esac
done

if [ -e "/home/testuser" ]; then
    export HOME=/home/testuser
fi
disable_suspend
wait_boot_completed "${TIMEOUT}"
wait_homescreen "${TIMEOUT}"

# Increase the heap size. KVM devices in LAVA default to ~250M of heap
export _JAVA_OPTIONS="-Xmx350M"
java -version

# Download CTS/VTS test package or copy it from local disk.
if echo "${TEST_URL}" | grep "^http" ; then
    wget -S --progress=dot:giga "${TEST_URL}"
else
    cp "${TEST_URL}" ./
fi
file_name=$(basename "${TEST_URL}")
unzip -q "${file_name}"
rm -f "${file_name}"

if [ -d "${TEST_PATH}/results" ]; then
    mv "${TEST_PATH}/results" "${TEST_PATH}/results_$(date +%Y%m%d%H%M%S)"
fi

# Run tradefed test.
info_msg "About to run tradefed shell on device ${ANDROID_SERIAL}"
./tradefed-runner.py -t "${TEST_PARAMS}" -p "${TEST_PATH}"

# Cleanup.
rm -f /etc/apt/sources.list.d/tradefed.list
