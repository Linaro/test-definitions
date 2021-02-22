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


def print_res(res, key):
    print("t{}-{}-latency pass {} us".format(res["t"], key, res[key]))


def get_block(filename):
    # Fetch a text block from the file iterating backwards. Each block
    # starts with an escape sequence which starts with '\x1b'.
    with open(filename, "rb") as f:
        try:
            f.seek(0, os.SEEK_END)
            while True:
                pe = f.tell()

                f.seek(-2, os.SEEK_CUR)
                while f.read(1) != b"\x1b":
                    f.seek(-2, os.SEEK_CUR)
                    pa = f.tell()

                blk = f.read(pe - pa)

                # Remove escape sequence at the start of the block
                # The control sequence ends in 'A'
                i = blk.find("A") + 1
                yield blk[i:]

                # Jump back to next block
                f.seek(pa - 1, os.SEEK_SET)
        except IOError:
            # No escape sequence found
            f.seek(0, os.SEEK_SET)
            yield f.read()


def get_lastlines(filename):
    for b in get_block(filename):
        # Ignore empty blocks
        if len(b.strip("\n")) == 0:
            continue

        return b.split("\n")


def parse_cyclictest(filename):
    fields = ["t", "min", "avg", "max"]

    r = re.compile("[ :\n]+")
    for line in get_lastlines(filename):
        if not line.startswith("T:"):
            continue

        data = [x.lower() for x in r.split(line)]
        res = {}
        it = iter(data)
        for e in it:
            if e in fields:
                res[e] = next(it)

        print_res(res, "min")
        print_res(res, "avg")
        print_res(res, "max")


def parse_pmqtest(filename):
    fields = ["min", "avg", "max"]

    rl = re.compile("[ ,:\n]+")
    rt = re.compile("[ ,#]+")
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
        res["t"] = "{}-{}".format(data[1], data[3])

        print_res(res, "min")
        print_res(res, "avg")
        print_res(res, "max")


def main():
    tool = sys.argv[1]
    logfile = sys.argv[2]
    if tool in ["cyclictest", "signaltest", "cyclicdeadline"]:
        parse_cyclictest(logfile)
    elif tool in ["pmqtest", "ptsematest", "sigwaittest", "svsematest"]:
        parse_pmqtest(logfile)


if __name__ == "__main__":
    main()
