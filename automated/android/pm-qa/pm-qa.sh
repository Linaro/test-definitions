#!/bin/sh -e
# shellcheck disable=SC1090

SKIP_INSTALL="false"
ANDROID_SERIAL=""
BOOT_TIMEOUT="300"

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/device-stdout.log"

BRANCH="android-arm64"
TESTS="cpufreq cpuidle cpuhotplug thermal cputopology"

. "${TEST_DIR}/../../lib/sh-test-lib"
. "${TEST_DIR}/../../lib/android-test-lib"

usage() {
    echo "Usage: $0 [-S <skip_install>] [-s <android_serial>] [-t <boot_timeout>] [-b <branch>] [-T <tests>]" 1>&2
    exit 1
}

while getopts ":S:s:t:b:T:" o; do
  case "$o" in
    S) SKIP_INSTALL="${OPTARG}" ;;
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    b) BRANCH="${OPTARG}" ;;
    T) TESTS="${OPTARG}" ;;
    *) usage ;;
  esac
done

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
adb_root

create_out_dir "${OUTPUT}"
install_deps "git wget" "${SKIP_INSTALL}"

rm -rf pm-qa
git clone https://git.linaro.org/power/pm-qa.git
cd pm-qa
git checkout "${BRANCH}"
cp "${TEST_DIR}"/device-script.sh ./
# If awk doesn't exist on the target, replace it with 'buysbox awk'.
if ! adb_shell_which awk; then
    info_msg "awk NOT found, replacing it with 'busybox awk'..."
    cp "${TEST_DIR}/../../bin/arm64/busybox" ./
    find . -name '*.sh' -exec sed -i 's/awk/busybox awk/g' '{}' \;
fi
cd ../

# glmark2 is required to heat GPU. Install it if it is not installed.
if ! adb shell pm list packages | grep 'glmark2'; then
    # The following link isn't available publicly.
    # Please copy the apk to the current directory for local run.
    info_msg "GLMark2 NOT installed, installing it..."
    test -f GLMark2.apk || wget http://testdata.validation.linaro.org/apks/GLMark2.apk
    adb install GLMark2.apk
fi

adb_push "pm-qa" "/data/local/tmp/pm-qa"
info_msg "device-${ANDROID_SERIAL}: About to run pm-qa test..."
adb shell /data/local/tmp/pm-qa/device-script.sh "${TESTS}" \
    | tee "${LOGFILE}"

grep -E "^[a-z0-9_]+: (pass|fail|skip)$" "${LOGFILE}" \
    | sed 's/://g' \
    | tee -a "${RESULT_FILE}"
