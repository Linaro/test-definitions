#!/usr/bin/env python3

# LAVA/OE glmark2 results parse script
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

import sys
import re

replaces = {
    " ": "_",
    "=": "-",
    "<": "[",
    ">": "]",
}

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: %s <result_file>" % sys.argv[0])
        sys.exit(1)

    rex = re.compile("(?P<test_case_id>.*): (?P<units>FPS): (?P<measurement>\\d+)")
    score_rex = re.compile("(?P<test_case_id>glmark2 Score): (?P<measurement>\\d+)")
    with open(sys.argv[1], 'r') as f:
        for line in f.readlines():
            m = rex.search(line)
            if m:
                case_id = m.group('test_case_id')
                for r in replaces.keys():
                    case_id = case_id.replace(r, replaces[r])
                result = 'pass'
                measurement = m.group('measurement')
                units = m.group('units')

                print("%s %s %s %s" % (case_id, result, measurement, units))
                continue

            m = score_rex.search(line)
            if m:
                case_id = m.group('test_case_id')
                for r in replaces.keys():
                    case_id = case_id.replace(r, replaces[r])
                result = 'pass'
                measurement = m.group('measurement')
                print("%s %s %s" % (case_id, result, measurement))
