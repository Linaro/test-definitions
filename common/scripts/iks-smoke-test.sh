# IKS smoke test
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
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>
#
# "CONFIG_BL_SWITCHER=y" is required in kernel config.
# Enable and disable big.LITTLE switcher can be done in run time by using
# userspace entry  "/sys/kernel/bL_switcher/active"
# This test is to enable and disable big.LITTLE IKS switcher 100 times.

ERR_CODE=0
switcher_disable ()
{
    echo 0 > /sys/kernel/bL_switcher/active
    ERR_CODE=$?
    if [ $ERR_CODE -ne 0 ]; then
        echo "not able to disable switcher"
        return 1
    fi
    return 0
}

switcher_enable ()
{
    echo 1 > /sys/kernel/bL_switcher/active
    ERR_CODE=$?
    if [ $ERR_CODE -ne 0 ]; then
        echo "not able to enable switcher"
        return 1
    fi
    return 0
}

check_iks()
{
    if [ -e /sys/kernel/bL_switcher/active ]; then
        echo "******************************"
        echo "IKS Implemented on this device"
        echo "******************************"
    else
        echo "IKS not implemented on this device"
        echo "skipping IKS tests"
        echo "enable-and-disable-switcher-100-times: SKIP"
        echo "IKS-smoke-test: SKIP"
        exit 0
    fi
}

check_kernel_oops()
{
    KERNEL_ERR=`dmesg | grep "Unable to handle kernel"`
    if [ -n "$KERNEL_ERR" ]; then
        echo "Kernel OOPS. Abort!!"
        return 1
    fi
    return 0
}

enable_and_disable_switcher_100_times()
{
    i=0
    while [ $i -lt 100 ]; do
        switcher_enable
        if [ $? -ne 0 ]; then
            return $?
        fi
        sleep 1
        switcher_disable
        if [ $? -ne 0 ]; then
            return $?
        fi
        i=$(($i + 1))
        echo "enable/disable IKS loop $i"
    done
}

check_iks
enable_and_disable_switcher_100_times
if [ $? -eq 0 ]; then
    echo "enable-and-disable-switcher-100-times: PASS"
else
    echo "enable-and-disable-switcher-100-times: FAIL"
fi
check_kernel_oops
if [ $? -eq 0 ]; then
    echo "IKS-smoke-test: PASS"
else
    echo "IKS-smoke-test: FAIL"
fi
exit 0
