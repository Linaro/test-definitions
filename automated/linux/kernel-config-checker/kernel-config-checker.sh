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

# Test run.
create_out_dir "${OUTPUT}"

info_msg "About to run kernel config checker test..."
info_msg "Output directory: ${OUTPUT}"

check_config "${CONFIG_VALUES}"
