#!/system/bin/sh
# shellcheck disable=SC2181
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
enabled_f="${LOGROOT}/enabled"
stop_f="${LOGROOT}/stop"

start_bootchart(){
    echo "${BOOTCHART_TIME}" > ${start_f}
    if [ $? -ne 0 ]; then
        echo "start_bootchart: fail"
    else
        echo "start_bootchart: pass"
    fi
}

enabled_bootchart(){
    touch ${enabled_f}
    if [ $? -ne 0 ]; then
        echo "enabled_bootchart: fail"
    else
        echo "enabled_bootchart: pass"
    fi
}

stop_bootchart(){
    echo 1 > ${stop_f}
    if [ $? -ne 0 ]; then
        echo "stop_bootchart: fail"
    else
        echo "stop_bootchart: pass"
    fi
    rm -fr ${start_f} ${enabled_f}
    if [ $? -ne 0 ]; then
        echo "rm_start_file: fail"
    else
        echo "rm_start_file: pass"
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
            # Wait the file to be sync disk completely
            sleep 5
            # copy bootchart logs to /data/local/tmp so that we can pull them
            # without root permissoin.
            cp -r /data/bootchart /data/local/tmp/
            ;;
        *)
            echo "bootchart: fail"
            ;;
    esac
}

main "$@"
