#!/bin/bash
#
# Device Tree test cases
#
# Copyright (C) 2016, Linaro Limited.
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
# Author: Ricardo Salveti <rsalveti@linaro.org>
# Maintainer: Naresh Kamboju <naresh.kamboju@linaro.org>

. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
SYSFS_DEVICE_TREE="/sys/firmware/devicetree/base/"
DEVICE_TREE="/proc/device-tree"
MODEL="model"
COMPATIBLE="compatible"

# Check if /proc/device-tree is available
device_tree() {
    if [ ! -d "${DEVICE_TREE}" ]; then
        report_fail "device-tree"
        error_msg "Unable to find ${DEVICE_TREE}"
    else
        info_msg ""${DEVICE_TREE}" directory is available"
        report_pass "device-tree"
    fi
}

# Check device tree property
device_tree_property() {
    [ "$#" -ne 1 ] && error_msg "Usage: device_tree_property test"
    local test="$1"

    DATA="$(cat "${DEVICE_TREE}/${test}")"
    if [ -z "${DATA}" ]; then
        report_fail "device-tree-"${test}""
        error_msg "Empty "${test}" description at "${DEVICE_TREE}"/"${test}""
    else
        info_msg "The "${test}" of the board is "${DATA}""
        report_pass "device-tree-"${test}""
    fi
}

# Test run.
! check_root && error_msg "This script must be run as root"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

CONFIG_PROC_FS=$(zcat /proc/config.gz | grep CONFIG_PROC_FS)
CONFIG_OF=$(zcat /proc/config.gz | grep "CONFIG_OF=")

if [ "${CONFIG_PROC_FS}" = "CONFIG_PROC_FS=y" ] && [ "${CONFIG_OF}" = "CONFIG_OF=y" ] && [ -d "${SYSFS_DEVICE_TREE}" ]
then
    device_tree
    device_tree_property "${MODEL}"
    device_tree_property "${COMPATIBLE}"
else
    report_fail "device-tree-test"
    error_msg "kernel options(CONFIG_PROC_FS and CONFIG_OF) for device-tree are not compiled or enabled."
fi
