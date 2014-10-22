#!/bin/sh
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

lshw > lshw.txt

if grep -E 'core' lshw.txt
then
    lava-test-case user-space-lshw-core-present --result pass
else
    lava-test-case user-space-lshw-core-present --result fail
fi

if grep 'firmware' lshw.txt
then
    lava-test-case user-space-lshw-firmware-has-info --result pass
else
    lava-test-case user-space-lshw-firmware-has-info --result fail
fi

if grep 'cpu' lshw.txt
then
    lava-test-case user-space-lshw-cpu-has-info --result pass
else
    lava-test-case user-space-lshw-cpu-has-info --result fail
fi

if grep 'network' lshw.txt
then
    lava-test-case user-space-lshw-network-has-info --result pass
else
    lava-test-case user-space-lshw-network-has-info --result fail
fi

if grep 'storage' lshw.txt
then
    lava-test-case user-space-lshw-storage-has-info --result pass
else
    lava-test-case user-space-lshw-storage-has-info --result fail
fi

cat lshw.txt
rm lshw.txt
