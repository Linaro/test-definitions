#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TEST_CMD="dmesg"
TEST_CMD_FILE="${OUTPUT}/${TEST_CMD}.txt"
# This will try to find all modules that ends with '*test.ko'
# Example KUNIT_TEST_MODULE="test.ko"
KUNIT_TEST_MODULE="test.ko"

usage() {
    echo "Usage: $0 [-m <kunit test module> ]" 1>&2
    exit 1
}

while getopts "m:h" o; do
  case "$o" in
    m) KUNIT_TEST_MODULE="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

run() {
    test="$1"
    "${test}" > "${TEST_CMD_FILE}"
    check_return "${test}"
}

# Example Test output to be parsed
# [   14.863117]     KTAP version 1
# [   14.863300]     # Subtest: fat_test
# [   14.863331]     1..3
# [   14.865700]     ok 1 fat_checksum_test
# [   14.865943]         KTAP version 1
# [   14.866295]         # Subtest: fat_time_fat2unix_test
# [   14.867871]         ok 1 Earliest possible UTC (1980-01-01 00:00:00)
# [   14.869285]         ok 2 Latest possible UTC (2107-12-31 23:59:58)
# [   14.871139]         ok 3 Earliest possible (UTC-11) (== 1979-12-31 13:00:00 UTC)
# [   14.872645]         ok 4 Latest possible (UTC+11) (== 2108-01-01 10:59:58 UTC)
# [   14.874433]         ok 5 Leap Day / Year (1996-02-29 00:00:00)
# [   14.876449]         ok 6 Year 2000 is leap year (2000-02-29 00:00:00)
# [   14.878015]         ok 7 Year 2100 not leap year (2100-03-01 00:00:00)
# [   14.879633]         ok 8 Leap year + timezone UTC+1 (== 2004-02-29 00:30:00 UTC)
# [   14.881756]         ok 9 Leap year + timezone UTC-1 (== 2004-02-29 23:30:00 UTC)
# [   14.883477]         ok 10 VFAT odd-second resolution (1999-12-31 23:59:59)
# [   14.885472]         ok 11 VFAT 10ms resolution (1980-01-01 00:00:00:0010)
# [   14.885871]     # fat_time_fat2unix_test: pass:11 fail:0 skip:0 total:11

parse_results() {
    test_log_file="$1"
    ./parse-output.py < "${test_log_file}" | tee -a "${RESULT_FILE}"
}

check_root || error_msg "Please run this script as root"
# Test run.
create_out_dir "${OUTPUT}"

find "/lib/modules/$(uname -r)" -name "*${KUNIT_TEST_MODULE}*"| tee /tmp/kunit_modules.txt
rm /tmp/kunit_module_names_not_loaded.txt 2>/dev/null
# find modules that isn't loaded
while read -r module; do
    module_name=$(basename "${module}" ".ko")
    if ! lsmod | grep "${module_name}"; then
        echo "${module_name}" | tee -a /tmp/kunit_module_names_not_loaded.txt
    fi
done < "/tmp/kunit_modules.txt"
if [ -f /tmp/kunit_module_names_not_loaded.txt ]
then
    while read -r module; do
        module_name=$(echo "${module}"|awk -F '/' '{print $NF}')
        echo KUNIT_TEST_MODULE="${module_name}"
        ln -s "${module}" \
        "/lib/modules/$(uname -r)/${module_name}"
    done < "/tmp/kunit_modules.txt"
    depmod -a
    while read -r module_name; do
        modprobe "${module_name}"
        exit_on_fail "modprobe-${module_name}"
        lsmod
    done < "/tmp/kunit_module_names_not_loaded.txt"
fi
if [ -f /proc/config.gz ]
then
    CONFIG_KUNIT_TEST=$(zcat /proc/config.gz | grep "CONFIG_KUNIT_TEST=")
elif [ -f /boot/config-"$(uname -r)" ]
then
    KERNEL_CONFIG_FILE="/boot/config-$(uname -r)"
    CONFIG_KUNIT_TEST=$(grep "CONFIG_KUNIT_TEST=" "${KERNEL_CONFIG_FILE}")
else
    info_msg "Kernel config file not available"
fi
if [ "${CONFIG_KUNIT_TEST}" = "CONFIG_KUNIT_TEST=y" ]
then
    info_msg "Kernel config CONFIG_KUNIT_TEST=y not enabled"
fi

run "${TEST_CMD}"
parse_results "${TEST_CMD_FILE}"
