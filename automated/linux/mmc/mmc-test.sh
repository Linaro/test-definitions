#!/bin/sh
#
# MMC test cases
#
# Copyright (C) 2017, Linaro Limited.
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
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>
#

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

# List the mmc devices
list_all_mmc_devices() {
    info_msg "Running list-all-mmc-devices test..."
    lsblk | grep "mmc"
    exit_on_fail "mmc"
}

# Test run.
! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

info_msg "About to run MMC test..."
info_msg "Output directory: ${OUTPUT}"

# Check kernel config
if [ -f /proc/config.gz ]
then
    CONFIG_MMC=$(zcat /proc/config.gz | grep "CONFIG_MMC=")
    CONFIG_MMC_SDHCI=$(zcat /proc/config.gz | grep "CONFIG_MMC_SDHCI=")
elif [ -f /boot/config-"$(uname -r)" ]
then
    KERNEL_CONFIG_FILE="/boot/config-$(uname -r)"
    CONFIG_MMC=$(grep "CONFIG_MMC=" "${KERNEL_CONFIG_FILE}")
    CONFIG_MMC_SDHCI=$(grep "CONFIG_MMC_SDHCI=" "${KERNEL_CONFIG_FILE}")
else
    exit_on_skip "mmc-pre-requirements" "Kernel config file not available"
fi

( [ "${CONFIG_MMC}" = "CONFIG_MMC=y" ] || [ "${CONFIG_MMC}" = "CONFIG_MMC=m" ] ) && ( [ "${CONFIG_MMC_SDHCI}" = "CONFIG_MMC_SDHCI=y" ] || [ "${CONFIG_MMC_SDHCI}" = "CONFIG_MMC_SDHCI=m" ] )
exit_on_skip "mmc-pre-requirements" "Kernel config CONFIG_MMC=y or CONFIG_MMC=m and CONFIG_MMC_SDHCI=y or CONFIG_MMC_SDHCI=m not enabled"

list_all_mmc_devices
