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
# default to set the wifi(when required) and check the internet when not specified or set to true
# which means it needs to specify explicitly to false to not check the internet access
INTERNET_ACCESS="true"
# Disable ENABLE_XTS_DYNAMIC_DOWNLOADER by default as suggested by google.
ENABLE_XTS_DYNAMIC_DOWNLOADER=${ENABLE_XTS_DYNAMIC_DOWNLOADER:-"false"}

check_internet_access() {
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
    DNS_TEST_SERVER_IP="8.8.8.8"

    info_msg "device-${ANDROID_SERIAL}: Checking network connectivity by pinging ${SERVER}..."

    # Try pinging www.google.com first
    if adb shell 'ping -c 10 '"${SERVER}"'; echo exitcode: $?' | grep -q "exitcode: 0"; then
        report_pass "network-available"
    else
        info_msg "Ping to ${SERVER} failed, testing DNS by pinging ${DNS_TEST_SERVER_IP}..."
        report_fail "network-available"

        # If ping to $DNS_TEST_SERVER_IP succeeds, it's likely a DNS issue
        if adb shell 'ping -c 10 '"${DNS_TEST_SERVER_IP}"'; echo exitcode: $?' | grep -q "exitcode: 0"; then
            report_pass "network-ping-to-dns-server-IP"

            # DNS-specific debug information
            info_msg "DNS resolution issue suspected; Since pinging ${DNS_TEST_SERVER_IP} worked; gathering DNS configuration information..."
            adb shell getprop || true  # As this is the failed case, display values of all properties, including the DNS settings

        else
            report_fail "network-ping-to-dns-server-IP"

            # General network debug information
            info_msg "Ping to ${DNS_TEST_SERVER_IP} failed too..."
            info_msg "Network connectivity issue detected; gathering debug information..."
            adb shell ip address || true
            adb shell ifconfig || true
        fi

        # Exit with error to trigger YAML file handling
        exit 100
    fi
}

usage() {
    echo "Usage: $0 [-o timeout] [-n serialno] [-c cts_url] [-t test_params] [-p test_path] [-r <aggregated|atomic>] [-f failures_printed] [-a <ap_ssid>] [-k <ap_key>] [ -i [true|false]] [-x [true|false]]" 1>&2
    exit 1
}

while getopts ':o:n:c:t:p:r:f:a:k:i:x:' opt; do
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
        i) INTERNET_ACCESS="${OPTARG}" ;; # if check the internet access
        x) ENABLE_XTS_DYNAMIC_DOWNLOADER="${OPTARG}" ;;
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
    # using kisscache to download the file, based on the following change:
    #    https://gitlab.com/lava/lava/-/merge_requests/2734
    # shellcheck disable=SC2153
    if [ -n "${HTTP_CACHE}" ]; then
        # and it's in the format like this:
        #     https://cache.lavasoftware.org/api/v1/fetch/?url=%s
        # so need to remove "%s" first here
        http_cache=$(echo "${HTTP_CACHE}"|sed 's|%s||')
        wget -S --progress=dot:giga "${http_cache}${TEST_URL}" -O "${file_name}"
    else
        wget -S --progress=dot:giga "${TEST_URL}" -O "${file_name}"
    fi
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

if [ "X${INTERNET_ACCESS}" = "Xtrue" ] || [ "X${INTERNET_ACCESS}" = "XTrue" ]; then
    check_internet_access
fi

export ENABLE_XTS_DYNAMIC_DOWNLOADER
# Run tradefed test.
info_msg "About to run tradefed shell on device ${ANDROID_SERIAL}"
./tradefed-runner.py -t "${TEST_PARAMS}" -p "${TEST_PATH}" -r "${RESULT_FORMAT}" -f "${FAILURES_PRINTED}"
