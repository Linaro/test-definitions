#!/system/bin/sh
#
# Linaro Android Boot Time Test
#
# Copyright (C) 2010 - 2014, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Botao Sun <botao.sun@linaro.org>

# Set delay time interval, as the test will be triggered once serial console available, though the GUI may not
delay_time=300
TEST="Android-Boot-Time"
sleep $delay_time

# Re-direct the dmesg output to a local file
dmesg_output_file="/data/data/dmesg_output.txt"
dmesg > $dmesg_output_file 2>&1
if [ $? -ne 0 ]; then
    echo "dmesg output re-direct failed, abort."
    return 1
fi

# Set default value for start point, end point and end flag
end_time_stamp=0
end_flag="name:service.bootanim.exit"

# Looking for the end flag in dmesg output
grep_return=`grep $end_flag $dmesg_output_file`
if [ $? -ne 0 ]; then
    echo "end flag search failed, abort."
    return 1
else
    echo $grep_return
    time_string=`echo $grep_return | awk '{print $2}'`
    echo $time_string
    integer_num=`echo $time_string | awk -F. '{print $1}'`
    echo $integer_num
    decimal_part=`echo $time_string | awk -F. '{print $2}'`
    decimal_num=`echo $decimal_part | cut -c 1-4`
    echo $decimal_num
    end_time_stamp=$integer_num"."$decimal_num
    echo $end_time_stamp
fi

# Submit the result
# Set the debug switcher, 0 is disable, 1 is enable
debug_switcher=0
if [ $debug_switcher -eq 0 ]; then
    lava-test-case $TEST --result pass --measurement $end_time_stamp --units "Seconds"
else
    echo "lava-test-case $TEST --result pass --measurement $end_time_stamp --units "Seconds""
fi

return 0
