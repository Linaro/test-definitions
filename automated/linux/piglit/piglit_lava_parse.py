#!/usr/bin/env python3

# LAVA/OE piglit results parse script
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
    if result == "warn":
        result = "pass"
    elif result == "crash":
        result = "fail"
    elif result == "incomplete":
        result = "fail"

    return result


def natural_keys(text):
    m = re.search(r"(\d+)", text)
    if m:
        return int(m.group(1))
    else:
        return text


def print_results(filename, ignore_tests):
    currentsuite = ""
    with open(filename, "r") as f:
        piglit_results = json.loads(f.read())
        for test in sorted(piglit_results["tests"].keys()):
            if test in ignore_tests:
                continue
            testname_parts = test.split("@")
            testname = testname_parts[-1].replace(" ", "_")
            suitename = "@".join(testname_parts[0:-1])

            if currentsuite != suitename:
                if currentsuite:
                    print("lava-test-set stop %s" % currentsuite)

                currentsuite = suitename
                print("lava-test-set start %s" % currentsuite)

            result = map_result_to_lava(piglit_results["tests"][test]["result"])
            print("%s %s" % (testname, result))
    print("lava-test-set stop %s" % currentsuite)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: %s <result_dir|result_file> [ignore_file]" % sys.argv[0])
        sys.exit(1)

    ignore_tests = []
    if len(sys.argv) == 3:
        with open(sys.argv[2], "r") as f:
            ignore_tests = f.read().split()

    if os.path.isdir(sys.argv[1]):
        for root, dirs, files in os.walk(sys.argv[1]):
            result_types = {}
            for name in sorted(files, key=natural_keys):
                if name.endswith(".tmp"):
                    continue
                piglit_result = None
                full_f = os.path.join(root, name)
                print_results(full_f, ignore_tests)
    else:
        print_results(sys.argv[1], ignore_tests)
