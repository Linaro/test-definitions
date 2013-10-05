#!/bin/sh
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
# Author: Avik Sil <avik.sil@linaro.org>
#

set -x

# Test user id
if [ `whoami` != 'root' ] ; then
    echo "You must be the superuser to run this script" >&2
    exit 1
fi

# Let's assume that only Ubuntu has apt-get...
if [ -e /usr/bin/apt-get ]; then
	# Install most appropriate linux-linaro-tools-* package
	KERNELVER=`uname -r | cut -f 1 -d'-'`
	PKGNAME=`apt-cache search "linux-linaro-tools-$KERNELVER" | head -1 | cut -f 1 -d' '`
	PERFBIN_PREFIX="/usr/bin/perf_"
	PERFBIN_VER=`uname -r | awk -F '-' '{print $1"-"$2}'`
	if [ ! -e $PERFBIN_PREFIX$PERFBIN_VER ]; then
		apt-get install --yes $PKGNAME
		PERFBIN=`dpkg -L $PKGNAME | grep perf_`
		if [ "$PERFBIN" != "$PERFBIN_PREFIX$PERFBIN_VER" ]; then
			ln -s $PERFBIN $PERFBIN_PREFIX$PERFBIN_VER
		fi
	fi
fi

# Test 'perf record'
echo "Performing perf record test..."
TCID="perf record test"
perf record -e cycles -o perf-lava-test.data stress -c 4 -t 10  2>&1 | tee perf-record.log
samples=`grep -ao "[0-9]\+[ ]\+samples" perf-record.log| cut -f 1 -d' '`
if [ $samples -gt 1 ]; then
    echo "$TCID : PASS"
else
    echo "$TCID : FAIL"
fi
rm perf-record.log

# Test 'perf report'
echo "Performing perf report test..."
TCID="perf report test"
perf report -i perf-lava-test.data 2>&1 | tee perf-report.log
pcnt_samples=`grep -c -e "^[ ]\+[0-9]\+.[0-9]\+%" perf-report.log`
if [ $pcnt_samples -gt 1 ]; then
    echo "$TCID : PASS"
else 
    echo "$TCID : FAIL"
fi
rm perf-report.log perf-lava-test.data

# Test 'perf stat'
echo "Performing perf stat test..."
TCID="perf stat test"
perf stat -e cycles stress -c 4 -t 10 2>&1 | tee perf-stat.log
cycles=`grep -o "[0-9,]\+[ ]\+cycles" perf-stat.log | sed 's/,//g' | cut -f 1 -d' '`
if [ $cycles -gt 1 ]; then
    echo "$TCID : PASS"
else
    echo "$TCID : FAIL"
fi
rm perf-stat.log

# Test 'perf test'
echo "Performing 'perf test'..."
TCID="perf test"
perf test 2>&1 | sed -e 's/FAILED!/FAIL/g' -e 's/Ok/PASS/g' -e "s/[ ]\?[0-9]\+:/$TCID -/g" -e 's/:/ :/g'
