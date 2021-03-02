#!/bin/sh
#
# Kernel config checker
#
# Checks if a set of CONFIG_* values are defined in the config file for a
# particular version of the Linux kernel.
#
# Copyright (C) 2019, Linaro Limited.
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
kernel_config=""

# A list of space-separated config values to be checked.
# Example: CONFIG_VALUES="CONFIG_X CONFIG_Y CONFIG_Z"
CONFIG_VALUES=''

usage() {
    echo "Usage: $0 [-c config_values]" 1>&2
    exit 1
}

while getopts "c:h" o; do
    case "$o" in
        c) CONFIG_VALUES="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

# Find the location of the kernel's config file based on various standard
# locations.
find_config_file() {
    if [ -e "/boot/config-$(uname -r)" ]; then
        kernel_config="/boot/config-$(uname -r)"
    elif [ -e "/lib/modules/$(uname -r)/config" ]; then
        kernel_config="/lib/modules/$(uname -r)/config"
    elif [ -e "/lib/kernel/config-$(uname -r)" ]; then
        kernel_config="/lib/kernel/config-$(uname -r)"
    elif [ -e "/proc/config.gz" ]; then
        tmpfile=$(mktemp /tmp/config.XXXXX)
        zcat /proc/config.gz > "${tmpfile}"
        kernel_config=${tmpfile}
    fi
}

check_config() {

    # Fetch the config file.
    find_config_file

    if [ ! -f "${kernel_config}" ]; then
        exit_on_fail "Kernel Config File ${kernel_config} does not exist..."
    fi

    info_msg "Found kernel config file in $kernel_config."

    # shellcheck disable=SC2068
    for c in ${@}; do
        info_msg "Checking config option ${c}..."
        cat < "${kernel_config}" | grep "${c}=[y|m]" > /dev/null
        check_return "config_value_${c}"
    done
}

# Test run.
create_out_dir "${OUTPUT}"

info_msg "About to run kernel config checker test..."
info_msg "Output directory: ${OUTPUT}"

check_config "${CONFIG_VALUES}"
