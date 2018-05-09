#!/usr/bin/env python3

# LAVA/OE gst-validate results parse script
#
# Copyright (C) 2018, Linaro Limited.
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
# Author: Aníbal Limón <anibal.limon@linaro.org>
#

import json
import os
import re
import sys


def map_result_to_lava(result):
    if result == 'Passed':
        result = 'pass'
    elif result == 'Failed':
        result = 'fail'
    elif result == 'Skipped':
        result = 'skip'
    elif result == 'Timeout':
        result = 'fail'

    return result


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: %s <result_file> [ignore_file]" % sys.argv[0])
        sys.exit(1)

    ignore_tests = []
    if len(sys.argv) == 3:
        with open(sys.argv[2], 'r') as f:
            ignore_tests = f.read().split()

    rex = re.compile('^(?P<test_case_id>validate\..*):\s+(?P<result>(Failed|Passed|Skipped|Timeout))')
    with open(sys.argv[1], 'r') as f:
        for line in f.readlines():
            s = rex.search(line)
            if s:
                test_case_id = s.group('test_case_id')
                result = s.group('result')

                if test_case_id not in ignore_tests:
                    print("%s %s" % (test_case_id, map_result_to_lava(result)))
