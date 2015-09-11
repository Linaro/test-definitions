#!/bin/sh
#
# Test device timings for block devices on ubuntu
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author:  Hanumantha Naradla <hanumantha.naradla@linaro.org>

if [ `whoami` != 'root' ] ; then
    echo "You must be the superuser to run this script" >&2
    exit 1
fi

. include/sh-test-lib

## Test case definitions
# Test device read timings (hdparm -t) and cache read timings (hdparm -T)

test_func(){
    test_cmd=$1
    c_read=0
    p_read=0
    t_read=0

    for i in 1 2 3;
    do
        echo ""
        echo "device read timings: Iteration $i"
        # Perform timings of cache reads
        hdparm -T /dev/$test_cmd
        # Perform timings of device reads in MB/sec
        c_read=`hdparm -t /dev/$test_cmd | grep 'reads' | awk -v col1=11 '{print $col1}'`
        if [ $c_read ]
        then
            echo "Device read timings: $c_read MB/sec"
        else
            echo "test_case_id:device_read_perf-$test_cmd units:none measurement:0 result:fail"
            return
        fi
        t_read=`echo $t_read $c_read | awk '{print $1+$2}'`
    done
        # Get average of device reads in MB/sec
        t_read=`echo $t_read | awk '{print $1/3}'`
        echo "Average device read timings: $t_read MB/sec"
        echo "test_case_id:device_read_perf-$test_cmd units:MBperSecond measurement:$t_read result:pass"
}

# Get total block devices
disk_count=`lsblk | grep disk -c`

if [ $disk_count -ge 1 ]
then
    echo "total block devices are $disk_count"
else
    echo "there are no block devices"
    echo "test_case_id:device_read_perf-* units:none measurement:0 result:skip" 
    exit 0
fi

# Test device timings for all devices
for i in `lsblk | grep 'disk' | awk -v col1=1 '{print $col1}'`
do
    test_func $i
done

# Clean exit so lava-test can trust the results
exit 0
