#!/system/bin/sh
#
# boot time test.
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
# Author: Yongqin Liu <yongqin.liu@linaro.org>
#
# Use the following information in logcat to record the android boot time
# I/SurfaceFlinger(  683): Boot is finished (91104 ms)

time_info=$(logcat -d -s SurfaceFlinger:I|grep -q "Boot is finished")
if [ -z "${time_info}" ]; then
    echo "boot_time: fail xx ms"
    exit 1
fi
time_value=$(echo "${time_info}"|cut -d\( -f3)
time_value=$(echo ${time_value}|cut -d\  -f1)
echo "boot_time: pass ${time_value} ms"
exit 0
