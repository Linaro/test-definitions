#!/bin/sh
#
# sysfs bus iio subsystem smoke tests
#
# Range checks for particular properties in the sysfs bus iio subsystem.
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

TESTNAME="sysfs bus iio subsystem smoke tests"

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# Path of the property file in the sysfs-bus-iio subsystem.
PROPERTY_PATH=""
# Minimum acceptable value for the property
PROPERTY_MIN_VALUE=""
# Maximum acceptable value for the property
PROPERTY_MAX_VALUE=""

usage() {
    echo "Usage: $0 -p property_path -b property_min_value -c property_max_value" 1>&2
    exit 1
}

while getopts "p:b:c:h" o; do
    case "$o" in
        p) PROPERTY_PATH="${OPTARG}" ;;
        b) PROPERTY_MIN_VALUE="${OPTARG}" ;;
        c) PROPERTY_MAX_VALUE="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

#
# Validate the input received by the test and bail out if anything is wrong.
#
validate_input()
{
  if [ -z "${PROPERTY_PATH}" ]; then
    info_msg "Property path is required."
    exit 1
  fi

  if [ ! -f "${PROPERTY_PATH}" ]; then
    info_msg "Property ${PROPERTY_PATH} not found."
    exit 1
  fi

  if [ -z "${PROPERTY_MIN_VALUE}" ] || [ -z "${PROPERTY_MAX_VALUE}" ]; then
    info_msg "Property's min/max values must be provided."
    exit 1
  fi

  return 0
}

validate_input

# Test run.
create_out_dir "${OUTPUT}"

info_msg "About to run $TESTNAME..."
info_msg "Output directory: ${OUTPUT}"

PROPERTY_VALUE="$(cat "$PROPERTY_PATH")"
check_return "Fetch property value from $PROPERTY_PATH"

if [ "$PROPERTY_VALUE" -gt "$PROPERTY_MAX_VALUE" ] || [ "$PROPERTY_VALUE" -lt "$PROPERTY_MIN_VALUE" ]; then
  report_fail "Property bounds check ($PROPERTY_PATH - [$PROPERTY_MIN_VALUE,$PROPERTY_MAX_VALUE]), found $PROPERTY_VALUE."
else
  report_pass "Property bounds check ($PROPERTY_PATH - [$PROPERTY_MIN_VALUE,$PROPERTY_MAX_VALUE]), found $PROPERTY_VALUE."
fi
