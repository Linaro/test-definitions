#!/bin/sh -ex

# shellcheck disable=SC1091
. ../../../lib/sh-test-lib
# shellcheck disable=SC1091
. ../../../lib/android-test-lib

TIMEOUT_SECS="300"
DEVICE_WORKER_MAPPING_FILE=""
TEST_URL="http://testdata.validation.linaro.org/cts/android-cts-7.1_r1.zip"
TEST_PARAMS="run cts -m CtsBionicTestCases --disable-reboot --skip-preconditions --skip-device-info"
TEST_RETRY_PARAMS="run cts --disable-reboot --skip-preconditions --skip-device-info"
MAX_NUM_RUNS="10"
RUNS_IF_UNCHANGED="3"
TEST_PATH="android-cts"
STATE_CHECK_FREQUENCY_SECS="60"
RESULT_FORMAT="aggregated"
RESULT_FILE="$(pwd)/output/result.txt"
export RESULT_FILE
# the default number of failed test cases to be printed
FAILURES_PRINTED="0"
# WIFI AP SSID
AP_SSID=""
# WIFI AP KEY
AP_KEY=""
JAVA_OPTIONS="-Xmx350M"

usage() {
    cat <<heredoc
Usage:
$0 [-o timeout_secs] [ -m device_worker_mapping_file] [-c cts_url]
[-t test_params] [-u test_retry_params] [-i max_num_runs] [-n runs_if_unchanged]
[-p test_path] [-s state_check_frequency_secs] [-r <aggregated|atomic>]
[-f failures_printed] [-a <ap_ssid>] [-k <ap_key>] [-j <java_options>]
[-b <userdata_image_file>]
heredoc
    exit 1
}

while getopts ':o:m:c:t:u:i:n:p:s:r:f:a:k:j:b:' opt; do
    case "${opt}" in
        o) TIMEOUT_SECS="${OPTARG}" ;;
        m) DEVICE_WORKER_MAPPING_FILE="${OPTARG}" ;;
        c) TEST_URL="${OPTARG}" ;;
        t) TEST_PARAMS="${OPTARG}" ;;
        u) TEST_RETRY_PARAMS="${OPTARG}" ;;
        i) MAX_NUM_RUNS="${OPTARG}" ;;
        n) RUNS_IF_UNCHANGED="${OPTARG}" ;;
        p) TEST_PATH="${OPTARG}" ;;
        s) STATE_CHECK_FREQUENCY_SECS="${OPTARG}" ;;
        r) RESULT_FORMAT="${OPTARG}" ;;
        f) FAILURES_PRINTED="${OPTARG}" ;;
        a) AP_SSID="${OPTARG}" ;;
        k) AP_KEY="${OPTARG}" ;;
        j) JAVA_OPTIONS="${OPTARG}" ;;
        b) USERDATA_IMAGE_FILE="${OPTARG}" ;;
        *) usage ;;
    esac
done

if [ -e "/home/testuser" ]; then
    export HOME=/home/testuser
fi

ANDROID_SERIALS=""
if [ -n "${DEVICE_WORKER_MAPPING_FILE}" ]; then
    deviceWorkerMapping="$(grep -ve '^$' "${DEVICE_WORKER_MAPPING_FILE}")"
    for deviceToWorker in ${deviceWorkerMapping}; do
        ANDROID_SERIALS="${ANDROID_SERIALS}$(echo "${deviceToWorker}" | cut -d';' -f1),"
    done
fi
ANDROID_SERIALS="${ANDROID_SERIALS%,}"


IFS=","; for ANDROID_SERIAL in ${ANDROID_SERIALS}; do
    info_msg "Processing device ${ANDROID_SERIAL}"
    export ANDROID_SERIAL; wait_boot_completed "${TIMEOUT_SECS}"
done; unset IFS

IFS=","; for ANDROID_SERIAL in ${ANDROID_SERIALS}; do
    info_msg "Processing device ${ANDROID_SERIAL}"
    export ANDROID_SERIAL; disable_suspend
done; unset IFS

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

# Increase the heap size. KVM devices in LAVA default to ~250M of heap
# This, however, breaks STS: the sts-tradefed script checks only the first line
# of `java -version` output, which becomes `Picked up _JAVA_OPTIONS: ...`.
# cts-tradefed checks for the first two lines and is therefore more robust here.
if [ "${TEST_PATH}" != "android-sts" ]; then
    export _JAVA_OPTIONS="${JAVA_OPTIONS}"
fi
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

# FIXME removing timer-suspend from vts test as it breaks the testing in lava
if [ -e "${TEST_PATH}/testcases/vts/testcases/kernel/linux_kselftest/kselftest_config.py" ]; then
    sed -i "/suspend/d" "${TEST_PATH}"/testcases/vts/testcases/kernel/linux_kselftest/kselftest_config.py
fi

# try to connect wifi if AP information specified
IFS=","; for ANDROID_SERIAL in ${ANDROID_SERIALS}; do
    info_msg "Processing device ${ANDROID_SERIAL}"
    export ANDROID_SERIAL; adb_join_wifi "${AP_SSID}" "${AP_KEY}"
done; unset IFS

# Run tradefed test.
info_msg "About to run tradefed shell on following devices: ${ANDROID_SERIALS}"

# This part is critical: if this is set, TradeFed will only connect to the one specified device.
unset ANDROID_SERIAL

runner_exited_cleanly="pass"
./tradefed-runner-multinode.py -t "${TEST_PARAMS}" -u "${TEST_RETRY_PARAMS}" -i "${MAX_NUM_RUNS}" \
    -n "${RUNS_IF_UNCHANGED}" -p "${TEST_PATH}" -s "${STATE_CHECK_FREQUENCY_SECS}" \
    -r "${RESULT_FORMAT}" -f "${FAILURES_PRINTED}" -m "${DEVICE_WORKER_MAPPING_FILE}" \
    --userdata_image_file "${USERDATA_IMAGE_FILE}" \
    || runner_exited_cleanly="fail"

# "fail" here means that an unexpected error/exception occurred in the runner.
# Expected exceptions will be caught in the runner and reported via
# `tradefed-test-run fail`
if [ "${runner_exited_cleanly}" = "fail" ]; then
    warn_msg "The TradeFed runner reported failure."
fi
echo "TradeFed-runner-exited-cleanly ${runner_exited_cleanly}" | tee -a "${RESULT_FILE}"

IFS=","; for ANDROID_SERIAL in ${ANDROID_SERIALS}; do
    info_msg "Processing device ${ANDROID_SERIAL}"
    export ANDROID_SERIAL; disable_suspend false || true
done; unset IFS

unset ANDROID_SERIAL

if [ "${runner_exited_cleanly}" = "fail" ]; then
    # Report failure to complete back to the test shell.
    exit 1
fi
