#!/system/bin/sh
#
# script to start and stop bootchart test.
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
. "${local_file_parent}/common.sh"

LOGROOT="/data/bootchart"
start_f="${LOGROOT}/start"
enabled_f="${LOGROOT}/enabled"
stop_f="${LOGROOT}/stop"
DATA_TMP="/data/local/tmp"
TARBALL="${DATA_TMP}/bootchart.tgz"

start_bootchart(){
    echo "${BOOTCHART_TIME}" > ${start_f}
    if [ $? -ne 0 ]; then
        output_test_result "start_bootchart" "fail"
    else
        output_test_result "start_bootchart" "pass"
    fi
}

enabled_bootchart(){
    touch ${enabled_f}
    if [ $? -ne 0 ]; then
        output_test_result "enabled_bootchart" "fail"
    else
        output_test_result "enabled_bootchart" "pass"
    fi
}

stop_bootchart(){
    echo 1 > ${stop_f}
    if [ $? -ne 0 ]; then
        output_test_result "stop_bootchart" "fail"
    else
        output_test_result "stop_bootchart" "pass"
    fi
    rm -fr ${start_f} ${enabled_f}
    if [ $? -ne 0 ]; then
        output_test_result "rm_start_file" "fail"
    else
        output_test_result "rm_start_file" "pass"
    fi
}

collect_data(){
    FILES="header proc_stat.log proc_ps.log proc_diskstats.log"
    if [ ! -d "${LOGROOT}" ]; then
        echo "There is no ${LOGROOT} directory!"
        return
    fi
    cd ${LOGROOT} || exit 1
    # shellcheck disable=SC2086
    tar -czvf ${TARBALL} ${FILES}
    if [ $? -ne 0 ]; then
        echo "bootchart_collect_data: fail"
    else
        echo "bootchart_collect_data: pass"
    fi
    # shellcheck disable=SC2086
    rm -fr ${FILES}
    cd ${DATA_TMP} || exit 1
    if [ -n "$(which lava-test-run-attach)" ]; then
        lava-test-run-attach bootchart.tgz application/x-gzip
    fi
    if [ -x "/system/bin/bootchart_parse" ]; then
        for line in $(/system/bin/bootchart_parse); do
            cmd="$(echo ${line} |cut -d, -f1)"
            start_time="$(echo ${line} |cut -d, -f2)"
            end_time="$(echo ${line} |cut -d, -f3)"
            output_test_result "${cmd}_starttime" "pass" "${start_time}" "ms"
            output_test_result "${cmd}_endtime" "pass" "${end_time}" "ms"
        done
    fi
}

main(){
    OPERATION="${1}"
    if [ "X${OPERATION}" = "X" ]; then
        OPERATION="stop"
    fi
    BOOTCHART_TIME="${2}"
    if [ "X${BOOTCHART_TIME}" = "X" ]; then
        BOOTCHART_TIME=120
    fi
    export BOOTCHART_TIME

    case "X${OPERATION}" in
        "Xstart")
            start_bootchart
            enabled_bootchart
            ;;
        "Xstop")
            stop_bootchart
            #wait the file to be sync disk completely
            sleep 5
            collect_data
            ;;
        *)
            echo "bootchart: fail"
            ;;
    esac
}

main "$@"
