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

LOGROOT="/data/bootchart"
start_f="${LOGROOT}/start"
stop_f="${LOGROOT}/stop"
DATA_TMP="/data/local/tmp"
TARBALL="${DATA_TMP}/bootchart.tgz"

start_bootchart(){
    echo "${BOOTCHART_TIME}" > ${start_f}
    if [ $? -ne 0 ]; then
        echo "start_bootchart: fail"
    else
        echo "start_bootchart: pass"
    fi
}

stop_bootchart(){
    echo 1 > ${stop_f} 
    if [ $? -ne 0 ]; then
        echo "stop_bootchart: fail"
    else
        echo "stop_bootchart: pass"
    fi
    rm ${start_f}
    if [ $? -ne 0 ]; then
        echo "rm_start_file: fail"
    else
        echo "rm_start_file: pass"
    fi
}

collect_data(){
    FILES="header proc_stat.log proc_ps.log proc_diskstats.log kernel_pacct"
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
