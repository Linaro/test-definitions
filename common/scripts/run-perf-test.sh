#!/bin/sh
# Copyright (C) 2012-2014, Linaro Limited.
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
# Author: Milosz Wasilewski <milosz.wasilewski@linaro.org>

set -x

# Test user id
if [ `whoami` != 'root' ] ; then
    echo "You must be the superuser to run this script" >&2
    exit 1
fi

# Test 'perf record'
echo "Performing perf record test..."
TCID="perf record test"
perf record -e cycles -o perf-lava-test.data stress -c 4 -t 10  2>&1 | tee perf-record.log
samples=`grep -ao "[0-9]\+[ ]\+samples" perf-record.log| cut -f 1 -d' '`
if [ $samples -gt 1 ]; then
    echo "$TCID : pass"
else
    echo "$TCID : fail"
fi
rm perf-record.log

# Test 'perf report'
echo "Performing perf report test..."
TCID="perf report test"
perf report -i perf-lava-test.data 2>&1 | tee perf-report.log
pcnt_samples=`grep -c -e "^[ ]\+[0-9]\+.[0-9]\+%" perf-report.log`
if [ $pcnt_samples -gt 1 ]; then
    echo "$TCID : pass"
else
    echo "$TCID : fail"
fi
rm perf-report.log perf-lava-test.data

# Test 'perf stat'
echo "Performing perf stat test..."
TCID="perf stat test"
perf stat -e cycles stress -c 4 -t 10 2>&1 | tee perf-stat.log
cycles=`grep -o "[0-9,]\+[ ]\+cycles" perf-stat.log | sed 's/,//g' | cut -f 1 -d' '`
if [ -z "$cycles" ]; then
    echo "$TCID : skip"
else
    if [ $cycles -gt 1 ]; then
        echo "$TCID : pass"
    else
        echo "$TCID : fail"
    fi
fi
rm perf-stat.log

# Test 'perf test'
echo "Performing 'perf test'..."
perf test -v 2>&1 | sed -e 's/FAILED!/fail/g' -e 's/Ok/pass/g' -e 's/:/ :/g'
