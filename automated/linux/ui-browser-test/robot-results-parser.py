#!/usr/bin/python
#
# Robot framework test results parser
#
# Copyright (c) 2016 Linaro Limited
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Naresh Kamboju <naresh.kamboju@linaro.org>

import sys
import xml.etree.ElementTree as ET

input_file = sys.argv[1]
tree = ET.parse(input_file)
root = tree.getroot()

for statistics in root.findall('statistics'):
    for suite in statistics.findall('suite'):
        for stat in suite.findall('stat'):
            name = stat.get('name')
            if 'Robot-Test-Scripts' == name:
                status = 'pass'
                print name, " ", status
            else:
                if '1' == stat.get('pass'):
                    status = 'pass'
                else:
                    status = 'fail'
                print name, " ", status
