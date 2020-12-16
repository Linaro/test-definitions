#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2016-2020 Linaro Ltd.
#
# Device Tree test cases
#
# Author: Ricardo Salveti <rsalveti@linaro.org>
# Maintainer: Naresh Kamboju <naresh.kamboju@linaro.org>

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
export RESULT_FILE="${OUTPUT}/result.txt"

SYSFS_DEVICE_TREE="/sys/firmware/devicetree/base/"
DEVICE_TREE="/proc/device-tree"
MODEL="model"
COMPATIBLE="compatible"
DT_SKIP_LIST="device-tree-${MODEL} device-tree-${COMPATIBLE}"

# Test run
create_out_dir "${OUTPUT}"

if [ -f /proc/config.gz ]; then
    CONFIG_PROC_FS=$(zcat /proc/config.gz | grep "CONFIG_PROC_FS=")
    CONFIG_OF=$(zcat /proc/config.gz | grep "CONFIG_OF=")
elif [ -f /boot/config-"$(uname -r)" ]; then
    KERNEL_CONFIG_FILE="/boot/config-$(uname -r)"
    CONFIG_PROC_FS=$(grep "CONFIG_PROC_FS=" "${KERNEL_CONFIG_FILE}")
    CONFIG_OF=$(grep "CONFIG_OF=" "${KERNEL_CONFIG_FILE}")
else
    exit_on_skip "device-tree-pre-requirements" "Kernel config file not available"
fi

# Check if kernel config is available
[ "${CONFIG_PROC_FS}" = "CONFIG_PROC_FS=y" ] && [ "${CONFIG_OF}" = "CONFIG_OF=y" ] && [ -d "${SYSFS_DEVICE_TREE}" ]
exit_on_fail "device-tree-Kconfig" "device_tree ${DT_SKIP_LIST}"

# Check if /proc/device-tree is available
[ -d "${DEVICE_TREE}" ]
exit_on_fail "device-tree" "${DT_SKIP_LIST}"

for dt_test in ${MODEL} ${COMPATIBLE}; do
    [ -n "$(cat "${DEVICE_TREE}/${dt_test}")" ]
    check_return "device-tree-${dt_test}"
done
