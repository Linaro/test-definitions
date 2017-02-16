#!/bin/sh
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

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

SYSFS_DEVICE_TREE="/sys/firmware/devicetree/base/"
DEVICE_TREE="/proc/device-tree"
MODEL="model"
COMPATIBLE="compatible"
DT_SKIP_LIST_1="device-tree-${MODEL} device-tree-${COMPATIBLE}"
DT_SKIP_LIST_2="device_tree ${DT_SKIP_LIST_1}"

# Check if /proc/device-tree is available
device_tree() {
    [ -d "${DEVICE_TREE}" ]
    exit_on_fail "device-tree" "${DT_SKIP_LIST_1}"
}

# Check device tree property
device_tree_property() {
    [ "$#" -ne 1 ] && error_msg "Usage: device_tree_property test"
    test="$1"

    DATA="$(cat "${DEVICE_TREE}/${test}")"
    [ -n "${DATA}" ]
    check_return "device-tree-${test}"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

if [ -f /proc/config.gz ]
then
    CONFIG_PROC_FS=$(zcat /proc/config.gz | grep "CONFIG_PROC_FS=")
    CONFIG_OF=$(zcat /proc/config.gz | grep "CONFIG_OF=")
elif [ -f /boot/config-"$(uname -r)" ]
then
    KERNEL_CONFIG_FILE="/boot/config-$(uname -r)"
    CONFIG_PROC_FS=$(grep "CONFIG_PROC_FS=" "${KERNEL_CONFIG_FILE}")
    CONFIG_OF=$(grep "CONFIG_OF=" "${KERNEL_CONFIG_FILE}")
else
    exit_on_skip "device-tree-pre-requirements" "Kernel config file not available"
fi

[ "${CONFIG_PROC_FS}" = "CONFIG_PROC_FS=y" ] && [ "${CONFIG_OF}" = "CONFIG_OF=y" ] && [ -d "${SYSFS_DEVICE_TREE}" ]
exit_on_fail "device-tree-Kconfig" "${DT_SKIP_LIST_2}"
device_tree
device_tree_property "${MODEL}"
device_tree_property "${COMPATIBLE}"
