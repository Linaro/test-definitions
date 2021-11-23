#!/bin/sh
#
# IMA smoke test
# Check if IMA is enabled in the kernel
# The test only checks kernel configs presence,
# IMA initialization and presence of measurements
# file. There is no comparison between measurements
# taken in different boot stages. There is also no
# requirement to use TPM.
#
# Copyright (C) 2021, Foundries.io
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# A list of space-separated config values to be checked.
# Example: CONFIG_VALUES="CONFIG_X CONFIG_Y CONFIG_Z"
CONFIG_VALUES='CONFIG_IMA CONFIG_IMA_NG_TEMPLATE CONFIG_IMA_DEFAULT_HASH_SHA256 CONFIG_IMA_WRITE_POLICY CONFIG_IMA_READ_POLICY CONFIG_IMA_APPRAISE CONFIG_IMA_APPRAISE_BOOTPARAM'
NEW_CONFIG_VALUES=""

usage() {
    echo "Usage: $0 [-c config_values]" 1>&2
    exit 1
}

while getopts "c:h" o; do
    case "$o" in
        c) NEW_CONFIG_VALUES="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

if [ -n "${NEW_CONFIG_VALUES}" ]; then
    CONFIG_VALUES="${NEW_CONFIG_VALUES}"
fi

echo "Using the following list of kernel configs: ${CONFIG_VALUES}"

! check_root && error_msg "You need to be root to run this script."
# Test run.
create_out_dir "${OUTPUT}"

info_msg "About to run kernl IMA smoke test..."
info_msg "Output directory: ${OUTPUT}"

check_config "${CONFIG_VALUES}"

# check dmesg for IMA initialization
dmesg | grep "ima: policy update completed"
check_return "ima_initialization"

# check if checksum files is present
test_name="ima_runtime_measurements"
measurement_file="/sys/kernel/security/ima/ascii_runtime_measurements"
if [ -f "${measurement_file}" ]; then
    report_pass "${test_name}"
    head -1 "${measurement_file}" | grep "boot_aggregate"
    check_return "ima_boot_aggregate"
else
    report_fail "${test_name}"
    report_skip "ima_boot_aggregate"
fi

