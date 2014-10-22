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
#
# Maintainer: Milosz Wasilewski <milosz.wasilewski@linaro.org>

dmidecode > dmidecode.txt

if grep -E 'SMBIOS [0-9]+.[0-9] present.' dmidecode.txt
then
    lava-test-case user-space-dmidecode-smbios-present --result pass
else
    lava-test-case user-space-dmidecode-smbios-present --result fail
fi

if grep 'BIOS Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-bios-has-info --result pass
else
    lava-test-case user-space-dmidecode-bios-has-info --result fail
fi

if grep 'System Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-system-has-info --result pass
else
    lava-test-case user-space-dmidecode-system-has-info --result fail
fi

if grep 'Base Board Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-baseboard-has-info --result pass
else
    lava-test-case user-space-dmidecode-baseboard-has-info --result fail
fi

if grep 'Chassis Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-chassis-has-info --result pass
else
    lava-test-case user-space-dmidecode-chassis-has-info --result fail
fi

if grep 'Processor Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-processor-has-info --result pass
else
    lava-test-case user-space-dmidecode-processor-has-info --result fail
fi

if grep 'Memory Device' dmidecode.txt
then
    lava-test-case user-space-dmidecode-memory-has-info --result pass
else
    lava-test-case user-space-dmidecode-memory-has-info --result fail
fi

if grep 'Cache Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-cache-has-info --result pass
else
    lava-test-case user-space-dmidecode-cache-has-info --result fail
fi

if grep 'Connector Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-connector-has-info --result pass
else
    lava-test-case user-space-dmidecode-connector-has-info --result fail
fi

if grep 'System Slot Information' dmidecode.txt
then
    lava-test-case user-space-dmidecode-slot-has-info --result pass
else
    lava-test-case user-space-dmidecode-slot-has-info --result fail
fi

cat dmidecode.txt
rm dmidecode.txt
