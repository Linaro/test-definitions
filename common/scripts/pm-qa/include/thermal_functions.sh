#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2011, Linaro Limited.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA
#
# Contributors:
#     Amit Daniel <amit.kachhap@linaro.org> (Samsung Electronics)
#       - initial API and implementation
#

THERMAL_PATH="/sys/devices/virtual/thermal"
MAX_ZONE=0-12
MAX_CDEV=0-50
ALL_ZONE=
ALL_CDEV=

check_valid_temp() {
    local file=$1
    local zone_name=$2
    local dir=$THERMAL_PATH/$2

    local temp_file=$dir/$1
    local func=cat
    shift 2;

    local temp_val=$($func $temp_file)
    local descr="'$zone_name'/'$file' ='$temp_val'"
    log_begin "checking $descr"

    if [ $temp_val -gt 0 ]; then
        log_end "pass"
        return 0
    fi

    log_end "fail"

    return 1
}

for_each_thermal_zone() {

    local func=$1
    shift 1

    zones=$(ls $THERMAL_PATH | grep "thermal_zone['$MAX_ZONE']")

    ALL_ZONE=$zone
    for zone in $zones; do
	INC=0
	$func $zone $@
    done

    return 0
}

get_total_trip_point_of_zone() {

    local zone_path=$THERMAL_PATH/$1
    local count=0
    shift 1
    trips=$(ls $zone_path | grep "trip_point_['$MAX_ZONE']_temp")
    for trip in $trips; do
	count=$((count + 1))
    done
    return $count
}

for_each_trip_point_of_zone() {

    local zone_path=$THERMAL_PATH/$1
    local count=0
    local func=$2
    local zone_name=$1
    shift 2
    trips=$(ls $zone_path | grep "trip_point_['$MAX_ZONE']_temp")
    for trip in $trips; do
	$func $zone_name $count
	count=$((count + 1))
    done
    return 0
}

for_each_binding_of_zone() {

    local zone_path=$THERMAL_PATH/$1
    local count=0
    local func=$2
    local zone_name=$1
    shift 2
    trips=$(ls $zone_path | grep "cdev['$MAX_CDEV']_trip_point")
    for trip in $trips; do
	$func $zone_name $count
	count=$((count + 1))
    done

    return 0

}

check_valid_binding() {
    local trip_point=$1
    local zone_name=$2
    local dirpath=$THERMAL_PATH/$2
    local temp_file=$2/$1
    local trip_point_val=$(cat $dirpath/$trip_point)
    get_total_trip_point_of_zone $zone_name
    local trip_point_max=$?
    local descr="'$temp_file' valid binding"
    shift 2

    log_begin "checking $descr"
    if [ $trip_point_val -ge $trip_point_max ]; then
        log_end "fail"
        return 1
    fi

    log_end "pass"
    return 0
}

validate_trip_bindings() {
    local zone_name=$1
    local bind_no=$2
    local dirpath=$THERMAL_PATH/$1
    local trip_point=cdev$2_trip_point
    shift 2

    check_file $trip_point $dirpath || return 1
    check_valid_binding $trip_point $zone_name || return 1
}

validate_trip_level() {
    local zone_name=$1
    local trip_no=$2
    local dirpath=$THERMAL_PATH/$1
    local trip_temp=trip_point_$2_temp
    local trip_type=trip_point_$2_type
    shift 2

    check_file $trip_temp $dirpath || return 1
    check_file $trip_type $dirpath || return 1
    check_valid_temp $trip_temp $zone_name || return 1
}

for_each_cooling_device() {

    local func=$1
    shift 1

    devices=$(ls $THERMAL_PATH | grep "cooling_device['$MAX_CDEV']")

    ALL_DEVICE=$devices
    for device in $devices; do
	INC=0
	$func $device $@
    done

    return 0
}
check_scaling_freq() {

    local before_freq_list=$1
    local after_freq_list=$2
    shift 2
    local index=0

    local flag=0
    for cpu in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
	if [ $before_freq_list[$index] != $afterf_req_list[$index] ] ; then
	    flag=1	
	fi
        index=$((index + 1)) 
    done
    return $flag
}

store_scaling_maxfreq() {
    scale_freq=
    local index=0

    for cpu in $(ls $CPU_PATH | grep "cpu[0-9].*"); do
	scale_freq[$index]=$(cat $CPU_PATH/$cpu/cpufreq/scaling_max_freq)
        index=$((index + 1))
    done
    return 0
}

get_trip_id() {

    local trip_name=$1
    shift 1

    local id1=$(echo $trip_name|cut -c12)
    local id2=$(echo $trip_name|cut -c13)
    if [ $id2 != "_" ]; then
	id1=$(($id2 + 10*$id1))
    fi
    return $id1
}

disable_all_thermal_zones() {

    mode_list=
    local index=0

    local th_zones=$(ls $THERMAL_PATH | grep "thermal_zone['$MAX_ZONE']")
    for zone in $th_zones; do
	mode_list[$index]=$(cat $THERMAL_PATH/$zone/mode)
        index=$((index + 1))
	echo -n "disabled" > $THERMAL_PATH/$zone/mode
    done
    return 0
}

enable_all_thermal_zones() {

    local index=0

    local th_zones=$(ls $THERMAL_PATH | grep "thermal_zone['$MAX_ZONE']")
    for zone in $th_zones; do
	echo $mode_list[$index] > $THERMAL_PATH/$zone/mode
        index=$((index + 1))
    done
    return 0
}

GPU_HEAT_BIN=/usr/bin/glmark2
gpu_pid=0

start_glmark2() {
    if [ -n "$ANDROID" ]; then
        am start org.linaro.glmark2/.Glmark2Activity
        return
    fi

    if [ -x $GPU_HEAT_BIN ]; then
        $GPU_HEAT_BIN &
        gpu_pid=$(pidof $GPU_HEAT_BIN)
        # Starting X application from serial console needs this
        if [ -z "$gpu_pid" ]; then
            cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.bk
            echo "autologin-user=root" >> /etc/lightdm/lightdm.conf
            export DISPLAY=localhost:0.0
            restart lightdm
            sleep 5
            mv /etc/lightdm/lightdm.conf.bk /etc/lightdm/lightdm.conf
            $GPU_HEAT_BIN &
            gpu_pid=$(pidof $GPU_HEAT_BIN)
        fi
        test -z "$gpu_pid" && cpu_pid=0
        echo "start gpu heat binary $gpu_pid"
    else
        echo "glmark2 not found." 1>&2
    fi
}

kill_glmark2() {
    if [ -n "$ANDROID" ]; then
        am kill org.linaro.glmark2
        return
    fi

    if [ "$gpu_pid" != 0 ]; then
	kill -9 $gpu_pid
    fi
}
