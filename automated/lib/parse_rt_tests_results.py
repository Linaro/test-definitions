#!/usr/bin/env python
# SPDX-License-Identifier: MIT
#
# MIT License
#
# Copyright (c) Daniel Wagner
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

import os
import re
import sys


def print_res(res, key, thr):
    val = res[key]
    label = 'pass'
    if key == 'max':
        if int(val) >= int(thr):
            label = 'fail'
    print('t{}-{}-latency {} {} us'.format(res['t'], key, label, val))


def get_lastlines(filename):
    # Start reading from the end of the file until ESC is found
    with open(filename, 'rb') as f:
        try:
            f.seek(-2, os.SEEK_END)
            while f.read(1) != b'\x1b':
                f.seek(-2, os.SEEK_CUR)
            return f.readlines()
        except IOError:
            # No ESC found
            f.seek(0, os.SEEK_SET)
            return f.readlines()
    return []


def parse_cyclictest(filename, thr):
    fields = ['t', 'min', 'avg', 'max']

    r = re.compile('[ :\n]+')
    for line in get_lastlines(filename):
        if not line.startswith('T:'):
            continue

        data = [x.lower() for x in r.split(line)]
        res = {}
        it = iter(data)
        for e in it:
            if e in fields:
                res[e] = next(it)

        print_res(res, 'min', thr)
        print_res(res, 'avg', thr)
        print_res(res, 'max', thr)


def parse_pmqtest(filename, thr):
    fields = ['min', 'avg', 'max']

    rl = re.compile('[ ,:\n]+')
    rt = re.compile('[ ,#]+')
    for line in get_lastlines(filename):
        data = [x.lower() for x in rl.split(line)]
        res = {}
        it = iter(data)
        for e in it:
            if e in fields:
                res[e] = next(it)

        if not res:
            continue

        # The id is constructed from the '#FROM -> #TO' output, e.g.
        # #1 -> #0, Min    1, Cur    3, Avg    4, Max  119
        data = rt.split(line)
        res['t'] = '{}-{}'.format(data[1], data[3])

        print_res(res, 'min', thr)
        print_res(res, 'avg', thr)
        print_res(res, 'max', thr)


def main():
    tool = sys.argv[1]
    if tool in ['cyclictest', 'signaltest']:
        parse_cyclictest(sys.argv[2], int(sys.argv[3]))
    elif tool in ['pmqtest', 'ptsematest']:
        parse_pmqtest(sys.argv[2], int(sys.argv[3]))


if __name__ == '__main__':
    main()
