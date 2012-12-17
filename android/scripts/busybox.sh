#!/system/bin/sh
#
# Busybox test.
#
# Copyright (C) 2012, Linaro Limited.
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
# Author: Senthil Kumaran <senthil.kumaran@linaro.org>
#

test_func(){
    if [ ! -f /system/bin/busybox ]; then
         echo "busybox=unexist"
         exit
    fi  

    if /system/bin/busybox [ $# -lt 1 ]; then
        return 0
    fi
    test_cmd=$1
    /system/bin/busybox "$@" 1>/dev/null 2>/dev/null
    if /system/bin/busybox [ $? -ne 0 ]; then
        echo "${test_cmd}=fail"
    else
        echo "${test_cmd}=pass"
    fi
}

rm -r /data/busybox 1>/dev/null 2>/dev/null

test_func mkdir /data/busybox
test_func touch /data/busybox/test.txt
test_func ls /data/busybox/test.txt
test_func ps
test_func whoami
test_func which busybox
test_func basename /data/busybox/test.txt
test_func cp /data/busybox/test.txt /data/busybox/test2.txt
test_func rm /data/busybox/test2.txt
test_func dmesg
test_func grep service /init.rc

rm -r /data/busybox 1>/dev/null 2>/dev/null
