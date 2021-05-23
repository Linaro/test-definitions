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

import sys
import json


def print_res(t, res, key):
    print("t{}-{}-latency pass {} us".format(t, key, res[key]))


def parse_threads(rawdata):
    num_threads = int(rawdata["num_threads"])
    for thread_id in range(num_threads):
        tid = str(thread_id)
        if "receiver" in rawdata["thread"][tid]:
            data = rawdata["thread"][tid]["receiver"]
        else:
            data = rawdata["thread"][tid]

        for k in ["min", "avg", "max"]:
            print_res(tid, data, k)


def parse_json(testname, filename):
    with open(filename) as file:
        rawdata = json.load(file)

    if "num_threads" in rawdata:
        # most rt-tests have generic per thread results
        parse_threads(rawdata)
    elif "inversions" in rawdata:
        # pi_stress
        print("inversion {}\n".format(rawdata("inversions")))

    if int(rawdata["return_code"]) == 0:
        print("{} pass".format(testname))
    else:
        print("{} fail".format(testname))


def main():
    parse_json(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
