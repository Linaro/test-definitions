#!/usr/bin/env python
#
# CTS test for Linaro Android.
#
# Copyright (C) 2010 - 2015, Linaro Limited.
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
import shlex
import urllib
import zipfile
import subprocess
import xml.etree.ElementTree as ET

# Switch to home path of current user to avoid any permission issue
home_path = os.environ['HOME']
os.chdir(home_path)
print os.getcwd()

debug_switcher = False
def collect_result(testcase_id, result):
    if debug_switcher is False:
        subprocess.call(['lava-test-case', testcase_id, '--result', result])
    else:
        print ['lava-test-case', testcase_id, '--result', result]

def result_parser(xml_file):
    tree = ET.parse(xml_file)
    # dump test result xml to stdout for debug
    if debug_switcher is True:
        ET.dump(tree)
    root = tree.getroot()
    print 'There are ' + str(len(root.findall('TestPackage'))) + ' Test Packages in this test result file: ' + xml_file
    testcase_counter = 0
    for elem in root.findall('TestPackage'):
        # Naming: Package Name + Test Case Name + Test Name
        if 'abi' in elem.attrib.keys():
            package_name = '.'.join([elem.attrib['abi'], elem.attrib['appPackageName']])
        else:
            package_name = elem.attrib['appPackageName']
        for testcase in elem.iter('TestCase'):
            testcase_name = testcase.attrib['name']
            for test in testcase.iter('Test'):
                testcase_counter = testcase_counter + 1
                test_name = test.attrib['name']
                testcase_id = '.'.join([package_name, testcase_name, test_name])
                result = test.attrib['result']
                collect_result(testcase_id, result)
    print 'There are ' + str(testcase_counter) + ' test cases in this test result file: ' + xml_file

# download and extract the CTS zip package
ctsurl = sys.argv[1]
ctsfile = urllib.urlretrieve(ctsurl, ctsurl.split('/')[-1])
with zipfile.ZipFile(ctsurl.split('/')[-1]) as z:
    z.extractall()
z.close()
os.chmod('android-cts/tools/cts-tradefed', 0755)

# receive user input from JSON file and run
cts_stdout = open('cts_stdout.txt', 'w')
command = 'android-cts/tools/cts-tradefed ' + ' '.join([str(para) for para in sys.argv[2:]])
print command
return_check = subprocess.call(shlex.split(command), stdout=cts_stdout)
print 'The return value of CTS command run is ' + str(return_check)
if return_check != 0:
    # even though the whole command may not run successfully, continue to submit the existing result anyway
    # add test case CTS-Command-Check to indicate this incident
    print 'CTS command: ' + command + ' run failed!'
    collect_result(testcase_id='CTS-Command-Check', result='fail')
cts_stdout.close()

# compress then attach the CTS stdout file to LAVA bundle
compress = 'xz -9 cts_stdout.txt'
subprocess.call(shlex.split(compress))
subprocess.call(['lava-test-run-attach', 'cts_stdout.txt.xz'])

# locate and parse the test result
result_dir = 'android-cts/repository/results'
test_result = 'testResult.xml'
dir_list = [os.path.join(result_dir, item) for item in os.listdir(result_dir) if os.path.isdir(os.path.join(result_dir, item))==True]
print dir_list
for item in dir_list:
    if test_result in os.listdir(item):
        result_parser(xml_file=os.path.join(item, test_result))
    else:
        print 'Could not find the test result file in ' + item + ', Skip!'
