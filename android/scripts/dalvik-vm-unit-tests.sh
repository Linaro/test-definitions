#!/system/bin/sh
#
# Dalvik-VM unit tests.
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
# Author: Amit Pundir <amit.pundir@linaro.org>
#

chmod 777 /data/nativetest/dalvik-vm-unit-tests/dalvik-vm-unit-tests
/data/nativetest/dalvik-vm-unit-tests/dalvik-vm-unit-tests
if [ $? -eq 0 ]; then
	echo "dalvik-vm-unit-tests=pass"
else
	echo "dalvik-vm-unit-tests=fail"
fi
