#!/bin/sh -ex

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../lib/android-test-lib

export PATH="$PWD/platform-tools:$PATH"
TIMEOUT="300"
TEST_URL="http://testdata.validation.linaro.org/cts/android-cts-7.1_r1.zip"
TEST_PARAMS="cts -m CtsBionicTestCases --abi arm64-v8a --disable-reboot --skip-preconditions --skip-device-info"
TEST_PATH="android-cts"
RESULT_FORMAT="aggregated"
RESULT_FILE="$(pwd)/output/result.txt"
DIR_RESULT_FILE="$(pwd)/output"
# create the directory for ${RESULT_FILE}
# so that report_pass and report_fail would work
mkdir -p "${DIR_RESULT_FILE}"
export RESULT_FILE
# the default number of failed test cases to be printed
FAILURES_PRINTED="0"
# WIFI AP SSID
AP_SSID=""
# WIFI AP KEY
AP_KEY=""

usage() {
    echo "Usage: $0 [-o timeout] [-n serialno] [-c cts_url] [-t test_params] [-p test_path] [-r <aggregated|atomic>] [-f failures_printed] [-a <ap_ssid>] [-k <ap_key>]" 1>&2
    exit 1
}

while getopts ':o:n:c:t:p:r:f:a:k:' opt; do
    case "${opt}" in
        o) TIMEOUT="${OPTARG}" ;;
        n) export ANDROID_SERIAL="${OPTARG}" ;;
        c) TEST_URL="${OPTARG}" ;;
        t) TEST_PARAMS="${OPTARG}" ;;
        p) TEST_PATH="${OPTARG}" ;;
        r) RESULT_FORMAT="${OPTARG}" ;;
        f) FAILURES_PRINTED="${OPTARG}" ;;
        a) AP_SSID="${OPTARG}" ;;
        k) AP_KEY="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ -e "/home/testuser" ]; then
    export HOME=/home/testuser
fi

wait_boot_completed "${TIMEOUT}"
disable_suspend
# wait_homescreen() searches logcat output for
# 'Displayed com.android.launcher', but the log might be washed away when
# a lot of logs generated after it. When the function not executed in
# time, error occurs. This has been observer several times on lkft
# testing. Refer to the following link:
    # https://lkft.validation.linaro.org/scheduler/job/18918#L4721
# We are already using wait_boot_completed() to check boot status, lets
# comment out wait_homescreen() and see if wait_boot_completed() is
# sufficient.
# wait_homescreen "${TIMEOUT}"

# Download CTS/VTS test package or copy it from local disk.
file_name=$(basename "${TEST_URL}")
if echo "${TEST_URL}" | grep "^http://lkft-cache.lkftlab/" ; then
    NO_PROXY=.lkftlab wget -S --progress=dot:giga "${TEST_URL}" -O "${file_name}"
elif echo "${TEST_URL}" | grep "^http" ; then
    wget -S --progress=dot:giga "${TEST_URL}" -O "${file_name}"
else
    cp "${TEST_URL}" "./${file_name}"
fi
unzip -q "${file_name}"
rm -f "${file_name}"

if [ -d "${TEST_PATH}/results" ]; then
    mv "${TEST_PATH}/results" "${TEST_PATH}/results_$(date +%Y%m%d%H%M%S)"
fi

# FIXME removing timer-suspend from vts test as it breaks the testing in lava
if [ -e "${TEST_PATH}/testcases/vts/testcases/kernel/linux_kselftest/kselftest_config.py" ]; then
    sed -i "/suspend/d" "${TEST_PATH}"/testcases/vts/testcases/kernel/linux_kselftest/kselftest_config.py
fi

if [ -n "${AP_SSID}" ] && [ -n "${AP_KEY}" ]; then
    # try to connect to wifi with the feature provided by tradefed by default
    # when AP_SSID and AP_KEY are specified for this tradefed test action explicitly
    TEST_PARAMS="${TEST_PARAMS} --wifi-ssid ${AP_SSID} --wifi-psk ${AP_KEY}"
else
    # try to connect to wifi with the external AdbJoinWifi apk from
    # https://github.com/steinwurf/adb-join-wifi
    # if AP_SSID and AP_KEY are not specified for this tradefed test action
    adb_join_wifi "${AP_SSID}" "${AP_KEY}"
fi

# wait for a while till the wifi connecting operation finished
sleep 60

SERVER="www.google.com"
info_msg "device-${ANDROID_SERIAL}: About to check with ping ${SERVER}..."
if adb shell 'ping -c 10 '"${SERVER}"'; echo exitcode: $?' | grep -q "exitcode: 0"; then
    report_pass "network-available"
else
    report_fail "network-available"
    # print more debug information on the DUT side
    adb shell ip address || true
    adb shell ip route || true
    adb shell ping -c 10 8.8.8.8 || true
    # ip of the dns server
    adb shell ping -c 10 10.66.16.15 || true
    # check "Setting DNS servers for network"
    # or "DnsResolverService::setResolverConfiguration"
    adb logcat -d resolv:V|grep -i dns
    # print more debug information on the host side
    ip address || true
    ip route || true
    cat /etc/resolv.conf
    ping -c 10 "${SERVER}" || true
    ping -c 10 8.8.8.8 || true
    # ip of the dns server
    ping -c 10 10.66.16.15 || true
    # to be caught by the yaml file
    exit 100
fi

# Run tradefed test.
info_msg "About to run tradefed shell on device ${ANDROID_SERIAL}"
./tradefed-runner.py -t "${TEST_PARAMS}" -p "${TEST_PATH}" -r "${RESULT_FORMAT}" -f "${FAILURES_PRINTED}"
