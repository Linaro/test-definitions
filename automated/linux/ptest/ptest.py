#!/usr/bin/env python3

# LAVA/OE ptest script
#
# Copyright (C) 2017, Linaro Limited.
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
import argparse
import subprocess
import re
import os

OUTPUT_LOG = os.path.join(os.getcwd(), 'result.txt')


def get_ptest_dir():
    ptest_dirs = ['/usr/lib', '/usr/lib64', '/usr/lib32']

    for pdir in ptest_dirs:
        try:
            ptests = subprocess.check_output('ptest-runner -l -d %s' %
                                             pdir, shell=True,
                                             stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError:
            continue

        return pdir

    return None


def get_available_ptests(ptest_dir):
    output = subprocess.check_output('ptest-runner -l -d %s' %
                                     ptest_dir, shell=True,
                                     stderr=subprocess.STDOUT)

    ptests = []
    ptest_rex = re.compile("^(?P<ptest_name>.*)\t")
    for line in output.decode('utf-8').split('\n'):
        m = ptest_rex.search(line)
        if m:
            ptests.append(m.group('ptest_name'))

    return ptests


def filter_ptests(ptests, requested_ptests):
    filter_ptests = []

    if not requested_ptests:
        return ptests

    for ptest_name in ptests:
        if ptest_name in requested_ptests:
            requested_ptests[ptest_name] = True
            filter_ptests.append(ptest_name)

    for request_ptest in requested_ptests.keys():
        if not requested_ptests[request_ptest]:
            print("ERROR: Ptest %s was requested and isn't available" %
                  request_ptest)
            sys.exit(1)

    return filter_ptests


def check_ptest(ptest_dir, ptest_name, output_log):
    status = 'pass'

    try:
        output = subprocess.check_call('ptest-runner -d %s %s' %
                                       (ptest_dir, ptest_name), shell=True,
                                       stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        status = 'fail'

    with open(output_log, 'a+') as f:
        f.write("%s %s\n" % (ptest_name, status))


def main():
    parser = argparse.ArgumentParser(description="LAVA/OE ptest script",
                                     add_help=False)
    parser.add_argument('-t', '--tests', action='store', nargs='*',
                        help='Ptests to run')
    parser.add_argument('-d', '--ptest-dir',
                        help='Directory where ptests are stored (optional)',
                        action='store')
    parser.add_argument('-o', '--output-log',
                        help='File to output log (optional)', action='store',
                        default=OUTPUT_LOG)
    parser.add_argument('-h', '--help', action='help',
                        default=argparse.SUPPRESS,
                        help='show this help message and exit')
    args = parser.parse_args()

    if args.ptest_dir:
        ptest_dir = args.ptest_dir
    else:
        ptest_dir = get_ptest_dir()
    if not ptest_dir:
        print("ERROR: No ptest dir found\n")
        return 1

    ptests = get_available_ptests(ptest_dir)
    if not ptests:
        print("ERROR: No ptests found in dir: %s\n" % ptest_dir)
        return 1

    # filter empty strings caused by -t ""
    tests = []
    if args.tests:
        tests = [x for x in args.tests if x]

    required_ptests = dict.fromkeys(tests, False)
    ptests_to_run = filter_ptests(ptests, required_ptests)
    for ptest_name in ptests_to_run:
        check_ptest(ptest_dir, ptest_name, args.output_log)

    return 0


if __name__ == '__main__':
    try:
        ret = main()
    except SystemExit as e:
        ret = e.code
    except:
        ret = 1
        import traceback
        traceback.print_exc()

    sys.exit(ret)
