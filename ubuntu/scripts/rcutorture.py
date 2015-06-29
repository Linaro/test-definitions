#!/usr/bin/env python
#
# RCU Torture test for Linux Kernel.
#
# Copyright (C) 2010 - 2014, Linaro Limited.
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
# Author: Botao Sun <botao.sun@linaro.org>

import os
import sys
import time
import shlex
import subprocess

# Result collection for LAVA
debug_switcher = False


def collect_result(testcase, result):
    if debug_switcher is False:
        subprocess.call(['lava-test-case', testcase, '--result', result])
    else:
        print ['lava-test-case', testcase, '--result', result]

# Switch to home path of current user
home_path = os.path.expanduser("~")
os.chdir(home_path)
print os.getcwd()

# RCU Torture start check
rcutorture_start = 'modprobe rcutorture'
rcutorture_time = sys.argv[1]
start_return = subprocess.call(shlex.split(rcutorture_start))
if start_return != 0:
    collect_result('rcutorture-start', 'fail')
    collect_result('rcutorture-module-check', 'skip')
    collect_result('rcutorture-end', 'skip')
    sys.exit(1)
else:
    print('RCU Torture test started. Test time is %s seconds'
          % (rcutorture_time))
    collect_result('rcutorture-start', 'pass')
    time.sleep(int(rcutorture_time))

# RCU Torture module check
lsmod_output = subprocess.check_output(['lsmod'])
print lsmod_output
lsmod_list = lsmod_output.split()
torture_list = filter(lambda x: x.find('torture') != -1, lsmod_list)
if len(torture_list) == 0:
    print 'Cannot find rcutorture module in lsmod, abort!'
    collect_result('rcutorture-module-check', 'fail')
    collect_result('rcutorture-end', 'skip')
    sys.exit(1)
else:
    collect_result('rcutorture-module-check', 'pass')

# RCU Torture result check
end_keyword = 'rcu-torture:--- End of test'
rcutorture_end = 'modprobe -r rcutorture'
end_return = subprocess.call(shlex.split(rcutorture_end))
if end_return != 0:
    print 'RCU Torture terminate command ran failed.'
    collect_result('rcutorture-end', 'fail')
    sys.exit(1)
else:
    keyword_counter = 0
    output = subprocess.check_output(['dmesg'])
    output_list = output.split('\n')
    for item in output_list:
        if end_keyword in item:
            keyword_counter = keyword_counter + 1
            print 'RCU Torture test has finished.'
            if 'SUCCESS' in item:
                collect_result('rcutorture-end', 'pass')
                sys.exit(0)
            else:
                print 'RCU Torture finished with issues.'
                collect_result('rcutorture-end', 'fail')
                sys.exit(1)

    if keyword_counter == 0:
        print 'Cannot find the ending of this RCU Torture test.'
        collect_result('rcutorture-end', 'fail')
