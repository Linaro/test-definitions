#!/system/bin/sh
#
# script to run "bootstat -p" to get the bootstat result.
#
# Copyright (C) 2014, Linaro Limited.
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
# Foundation, Inc., 51   Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.
#
# owner: yongqin.liu@linaro.org
#
###############################################################################

local_file_path="$0"
local_file_parent=$(dirname "${local_file_path}")
local_file_parent=$(cd "${local_file_parent}"||exit; pwd)
# shellcheck source=android/scripts/common.sh
. "${local_file_parent}/../../../android/scripts/common.sh"

DATA_TMP="/data/local/tmp"

collect_data(){
    local bootstat_cmd="/system/bin/bootstat"
    local bootstat_res="${DATA_TMP}/bootstat.result"
    if [ -x "${bootstat_cmd}" ]; then
        ${bootstat_cmd} -p | grep -v "Boot events" | grep -v '\--------'> "${bootstat_res}"
        if [ $? -ne 0 ]; then
            output_test_result "bootstat" "fail"
            exit 1
        else
            output_test_result "bootstat" "pass"
            while read -r line; do
                local test_case=$(echo "${line}" | awk '{print $1}')
                local measurement=$(echo "${line}" | awk '{print $2}')
                if [ "X${test_case}" = "Xboot_reason" ]; then
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "number"
                elif echo "${test_case}" | grep -q "ro.boottime.init"; then
                    # ro.boottime.init
                    # ro.boottime.init.selinux
                    # ro.boottime.init.cold_boot_wait
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "ms"
                elif echo "${test_case}" | grep -q "boottime.bootloader"; then
                    # boottime.bootloader.*
                    # boottime.bootloader.total
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "ms"
                elif [ "X${test_case}" = "Xtime_since_last_boot" ]; then
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                elif [ "X${test_case}" = "Xlast_boot_time_utc" ]; then
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                elif [ "X${test_case}" = "Xabsolute_boot_time" ]; then
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                elif [ "X${test_case}" = "Xbuild_date" ]; then
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                elif echo "${test_case}" | grep -q "boot_complete"; then
                    # boot_complete
                    # boot_complete_no_encryption
                    # factory_reset_boot_complete
                    # factory_reset_boot_complete_no_encryption
                    # ota_boot_complete
                    # ota_boot_complete_no_encryption
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                elif echo "${test_case}" | grep -q "factory_reset"; then
                    # factory_reset
                    # factory_reset_current_time
                    # factory_reset_record_value
                    # time_since_factory_reset
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "second"
                else
                    output_test_result "bootstat_${test_case}" "pass" "${measurement}" "unknown"
                fi
            done < "${bootstat_res}"

            cd ${DATA_TMP} || exit 1
            if [ -n "$(which lava-test-run-attach)" ]; then
                [ -f "bootstat.result" ] && lava-test-run-attach bootstat.result text/plain
                [ -f "lava_test_shell_raw_data.csv" ] && lava-test-run-attach lava_test_shell_raw_data.csv text/plain
            fi
            rm -fr "${bootstat_res}"
        fi
    fi
}

main(){
    collect_data
}

main "$@"
