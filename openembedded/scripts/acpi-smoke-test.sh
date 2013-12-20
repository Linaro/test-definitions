#! /bin/bash
#
# Test ACPI Support in UEFI on v7 and v8
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
#
DSDTPASS=
echo -n "Testing presence of /sys/firmware/acpi: "
if [ -d /sys/firmware/acpi ]; then
    lava-test-case sys-firmware-acpi-present --result pass
else
    lava-test-case sys-firmware-acpi-present --result fail
fi
echo -n "Testing presence of /sys/firmware/acpi/tables/DSDT: "
if [ -f /sys/firmware/acpi/tables/DSDT ]; then
    lava-test-case sys-firmware-acpi-tables-DSDT --result pass
    DSDTPASS=pass
else
    lava-test-case sys-firmware-acpi-tables-DSDT --result fail
fi
echo -n "Can decompile DSDT: "
if [ -x /usr/bin/iasl -a -n "$DSDTPASS" ]; then
    cp /sys/firmware/acpi/tables/DSDT /tmp/
    ERROR=`/usr/bin/iasl -d /tmp/DSDT 2>&1 | grep DSDT.dsl`
    if [ -n "$ERROR" ]; then
        lava-test-case can-decompile-DSDT --result pass
    else
        lava-test-case can-decompile-DSDT --result fail
    fi
    rm /tmp/DSDT /tmp/DSDT.dsl
else
    lava-test-case can-decompile-DSDT --result skip
fi
