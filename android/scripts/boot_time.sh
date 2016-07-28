#!/system/bin/sh
#
# Android boot time test.
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Yongqin Liu <yongqin.liu@linaro.org>
# Author: Milosz Wasilewski <milosz.wasilewski@linaro.org>
#
# Use the following information in logcat to record the android boot time
# I/SurfaceFlinger( 683): Boot is finished (91104 ms)
# Use dmesg to check the boot time from beginning of clock ticks
# to the moment rootfs is mounted.
# The test requires dc to be available in rootfs

CONSOLE_SECONDS_START=`dmesg | awk '{print $2}' | awk -F "]" '{print $1}' | grep -v "^0.0" | head -n 1`
CONSOLE_SECONDS_END=`dmesg | grep "Freeing unused kernel memory" | tail -n 1 | tr -s " " | cut -d [ -f 2 | cut -d ] -f 1`
echo "$CONSOLE_SECONDS_END $CONSOLE_SECONDS_START - p"
CONSOLE_SECONDS=`echo "$CONSOLE_SECONDS_END $CONSOLE_SECONDS_START - p" | dc`

echo "TEST KERNEL_BOOT_TIME: pass $CONSOLE_SECONDS s"

TIME_INFO=$(logcat -d -s SurfaceFlinger:I|grep "Boot is finished")
if [ -z "${TIME_INFO}" ]; then
    echo "TEST ANDROID_BOOT_TIME: fail -1 ms"
else
    while echo "${TIME_INFO}"|grep -q "("; do
        TIME_INFO=$(echo "${TIME_INFO}"|cut -d\( -f2-)
    done
    TIME_VALUE=$(echo "${TIME_INFO}"|cut -d\  -f1)
    echo "TEST ANDROID_BOOT_TIME: pass ${TIME_VALUE} ms"
fi

SERVICE_START_TIME_INFO=$(dmesg |grep "healthd:"|head -n 1)
SERVICE_START_TIME_END=$(echo "$SERVICE_START_TIME_INFO"|cut -d] -f 1|cut -d[ -f2| tr -d " ")
if [ -z "${SERVICE_START_TIME_END}" ]; then
    echo "TEST ANDROID_SERVICE_START_TIME: fail -1 s"
else
    SERVICE_START_TIME=`echo "$SERVICE_START_TIME_END $CONSOLE_SECONDS_START - p" | dc`
    echo "TEST ANDROID_SERVICE_START_TIME: pass ${SERVICE_START_TIME} s"
fi

echo "$CONSOLE_SECONDS $TIME_VALUE 1000 / + p"
TOTAL_SECONDS=`echo "$CONSOLE_SECONDS $TIME_VALUE 1000 / + p" | dc`
echo "TEST TOTAL_BOOT_TIME: pass $TOTAL_SECONDS s"
exit 0
