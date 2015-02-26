#!/usr/bin/env python
#
# Phoronix test for Linux Linaro ubuntu
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
import pexpect
import sys
from subprocess import call, check_output

# Switch to home path of current user
home_path = os.path.expanduser("~")
os.chdir(home_path)
print os.getcwd()

# Result collection for LAVA
debug_switcher = False


def collect_result(testcase, result):
    if debug_switcher is False:
        call(['lava-test-case', testcase, '--result', result])
    else:
        print ['lava-test-case', testcase, '--result', result]


def collect_score_with_measurement(testcase, result, score, unit):
    if debug_switcher is False:
        call(['lava-test-case', testcase, '--result', result, '--measurement', str(score), '--units', unit])
    else:
        print ['lava-test-case', testcase, '--result', result, '--measurement', str(score), '--units', unit]


# Installation check
def phoronix_install_check():
    testcase = 'phoronix-install'
    call_return = call(['which', 'phoronix-test-suite'])
    if call_return != 0:
        result = 'fail'
        print 'Fatal error! Can not find phoronix command!'
        collect_result(testcase, result)
        sys.exit(1)
    else:
        result = 'pass'
        collect_result(testcase, result)

phoronix_install_check()

# Walk through the user agreement - one shot
phoronix_home = home_path + '/.phoronix-test-suite'
if os.path.isdir(phoronix_home) != True:
    user_agreement = pexpect.spawn('phoronix-test-suite version')
    user_agreement.logfile = open(home_path + '/phoronix-user-agreement-log.txt', 'w')
    user_agreement.expect('.+Do you agree to these terms and wish to proceed.+: ')
    user_agreement.sendline('Y')
    user_agreement.expect('.+Enable anonymous usage / statistics reporting.+: ')
    user_agreement.sendline('n')
    user_agreement.expect('.+Enable anonymous statistical reporting of installed software / hardware.+: ')
    user_agreement.sendline('n')
else:
    pass

# Set batch mode to automate run the test
batchmode_setup = pexpect.spawn('phoronix-test-suite batch-setup')
batchmode_setup.logfile = open(home_path + '/phoronix-batch-mode-setup-log.txt', 'w')
batchmode_setup.expect('.+Save test results when in batch mode.+: ')
batchmode_setup.sendline('Y')
batchmode_setup.expect('.+Open the web browser automatically when in batch mode.+: ')
batchmode_setup.sendline('N')
batchmode_setup.expect('.+Auto upload the results to OpenBenchmarking.+: ')
batchmode_setup.sendline('n')
batchmode_setup.expect('.+Prompt for test identifier.+: ')
batchmode_setup.sendline('n')
batchmode_setup.expect('.+Prompt for test description.+: ')
batchmode_setup.sendline('n')
batchmode_setup.expect('.+Prompt for saved results file-name.+: ')
batchmode_setup.sendline('Y')
batchmode_setup.expect('.+Run all test options.+: ')
batchmode_setup.sendline('Y')

# Print configuration file to stdout
call(['cat', home_path + '/.phoronix-test-suite/user-config.xml'])

# Get all Ethernet interface name
# As the input is trusted, then call the function in this way
eth_interface_list = check_output("ifconfig -a | grep eth | awk '{print $1}'", shell=True).split('\n')
eth_interface_list = filter(None, eth_interface_list)
print eth_interface_list

# Define test list
test_list = ['system-decompress-xz', 'stream']

# Run all the test
for i in range(0, len(test_list)):
    test_install = call(['phoronix-test-suite', 'batch-install', test_list[i]])
    if test_install != 0:
        print 'Fatal error! Failed to install ' + test_list[i] + '! Abort!'
        collect_result(test_list[i], 'skip')
    else:
        test_run = pexpect.spawn('phoronix-test-suite batch-run ' + test_list[i], timeout=None)
        test_run.expect('.+Enter a name to save these results under: ')
        test_run.sendline(test_list[i] + '-linaro')
        if test_run.isalive() == True:
            test_run.wait()
            test_result_file = home_path + '/.phoronix-test-suite/test-results/' + test_list[i] + '-linaro/' + 'test-1.xml'
            call(['cat', test_result_file])
            collect_result(test_list[i], 'pass')
        else:
            print 'Test process has died!'
            collect_result(test_list[i], 'fail')
