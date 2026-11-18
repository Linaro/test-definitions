#!/usr/bin/env python3
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


def print_thread_res(tid, res, key):
    print("t{}-{}-latency pass {} us".format(tid, key, res[key]))


def print_irq_res(iid, res, key):
    print("i{}-{}-latency pass {} us".format(iid, key, res[key]))


def print_user_res(uid, res, key):
    print("u{}-{}-latency pass {} us".format(uid, key, res[key]))


def ids(rawdata, section, count):
    """The ids of rawdata[section]: 0..count-1, or for the rtla tests,
    which key their results by CPU, the CPUs they measured."""
    keys = [str(i) for i in range(int(rawdata[count]))]
    if not all(k in rawdata[section] for k in keys):
        keys = sorted(rawdata[section], key=int)
    return keys


def not_latencies(testname, tids):
    """Threads whose results are by the test's design, not latencies.

    rt-migrate-test starts one task more than there are CPUs, all at
    once, each running for 20 ms; the lowest priority one, thread 0,
    waits for a CPU until another task is done (max ~20000 us). The
    other threads' start delays are the latencies.

    signaltest passes a signal around its threads; thread 0 sleeps 10 ms
    every 16 round trips, which the other threads' round trips include
    (max ~10000 us). Only thread 0 measures the round trip alone.
    """
    if testname == "rt-migrate-test":
        return {"0"}
    if testname == "signaltest":
        return set(tids) - {"0"}
    return set()


def parse_threads(rawdata, testname):
    tids = ids(rawdata, "thread", "num_threads")
    skip = not_latencies(testname, tids)
    for tid in tids:
        if tid in skip:
            continue
        if "receiver" in rawdata["thread"][tid]:
            data = rawdata["thread"][tid]["receiver"]
        else:
            data = rawdata["thread"][tid]

        for key in ["min", "avg", "max"]:
            print_thread_res(tid, data, key)


def parse_irqs(rawdata):
    for iid in ids(rawdata, "irq", "num_irqs"):
        data = rawdata["irq"][iid]
        for key in ["min", "avg", "max"]:
            print_irq_res(iid, data, key)


def parse_users(rawdata):
    # rtla-timerlat's user-space threads
    for uid in ids(rawdata, "user", "num_users"):
        for key in ["min", "avg", "max"]:
            print_user_res(uid, rawdata["user"][uid], key)


def parse_json(testname, filename):
    with open(filename) as file:
        rawdata = json.load(file)

    if "num_threads" in rawdata:
        # most rt-tests have generic per thread results
        parse_threads(rawdata, testname)
    if "num_users" in rawdata:
        parse_users(rawdata)
    if "num_irqs" in rawdata:
        # rlta timertat also knows about irqs
        parse_irqs(rawdata)

    elif "inversion" in rawdata:
        # pi_stress
        print("inversion pass {} count\n".format(rawdata["inversion"]))

    if int(rawdata["return_code"]) == 0:
        print("{} pass".format(testname))
    else:
        print("{} fail".format(testname))


def main():
    parse_json(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
