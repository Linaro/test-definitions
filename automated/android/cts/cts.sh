#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

JDK="openjdk-8-jdk-headless"
CTS_URL="http://testdata.validation.linaro.org/cts/android-cts-7.1_r1.zip"
TEST_PARAMS="run cts -m CtsBionicTestCases --disable-reboot --skip-preconditions --skip-device-info"
PKG_DEPS="wget zip xz-utils python-lxml python-setuptools python-pexpect aapt android-tools-adb android-tools-fastboot"

usage() {
    echo "Usage: $0 [-s <true|false>] [-n serialno] [-d jdk-version] [-r jre-version] [-c cts_url] [-t test_params]" 1>&2
    exit 1
}

while getopts ':s:n:d:r:c:t:' opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        n) SN="${OPTARG}" ;;
        d) JDK="${OPTARG}" ;;
        c) CTS_URL="${OPTARG}" ;;
        t) TEST_PARAMS="${OPTARG}" ;;
        *) usage ;;
    esac
done

test -z "${SN}" && export SN
initialize_adb

install_deps "${PKG_DEPS} ${JDK}" "${SKIP_INSTALL}"

# Increase the heap size. KVM devices in LAVA default to ~250M of heap
export _JAVA_OPTIONS="-Xmx350M"
java -version

if echo "${CTS_URL}" | grep "^http" ; then
    wget "${CTS_URL}"
    file_name=$(basename "${CTS_URL}")
    unzip "${file_name}"
    rm -f "${file_name}"
else
    # For local run, set ${CTS_URL} to local android-cts copy so that
    # you don't have to download it every time.
    # For example: ~/Downloads/android-cts
    cp -r "${CTS_URL}" ./
fi

if [ -d android-cts/results ]; then
    mv android-cts/results "android-cts/results_$(date +%Y%m%d%H%M%S)"
fi

./cts-runner.py -t "${TEST_PARAMS}" -n "${SN}"
