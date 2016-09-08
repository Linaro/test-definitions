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
# Author: Milosz Wasilewski <milosz.wasilewski@linaro.org>
# Author: Chase Qi <chase.qi@linaro.org>

import datetime
import gzip
import os
import sys
import shlex
import shutil
import subprocess
import threading
import urllib
import xml.etree.ElementTree as ET
import zipfile
import pexpect
import time

CTS_STDOUT = "cts_stdout.txt"
CTS_LOGCAT = "cts_logcat.txt"


class Command(object):
    def __init__(self, cmd):
        self.cmd = cmd
        self.process = None

    def run(self, timeout):
        def target():
            print '%s' % datetime.datetime.now()
            self.process = subprocess.Popen(self.cmd, shell=True)
            self.process.communicate()

        thread = threading.Thread(target=target)
        thread.start()

        thread.join(timeout)
        if thread.is_alive():
            print 'Terminating process'
            self.process.terminate()
            thread.join()
        return self.process.returncode


class Heartbeat(threading.Thread):
    def __init__(self, serial, process_list):
        threading.Thread.__init__(self)
        self.serial = serial
        self.process_list = process_list
        self.adb_ping = Command("adb -s %s shell echo \"OK\"" % serial)
        self._finished = threading.Event()
        self._interval = 30.0

    def setInterval(self, interval):
        self._interval = interval

    def shutdown(self):
        for process in self.process_list:
            print "terminating process: %s" % process.pid
            if process.poll() is None:
                process.kill()
        self._finished.set()

    def run(self):
        while 1:
            if self._finished.isSet(): return
            return_code = self.adb_ping.run(timeout=10)
            if return_code != 0:
                # terminate the test as adb connection is lost
                print "terminating CTS for %s" % self.serial
                for process in self.process_list:
                    print "terminating process: %s" % process.pid
                    if process.poll() is None:
                        process.kill()
                self._finished.set()
            else:
                print "%s is alive" % self.serial
            self._finished.wait(self._interval)


# Switch to home path of current user to avoid any permission issue
home_path = os.environ['HOME']
# os.chdir(home_path)
print os.getcwd()

debug_switcher = False
# def collect_result(testcase_id, result):
#    if debug_switcher is False:
#        subprocess.call(['lava-test-case', testcase_id, '--result', result])
#    else:
#        print ['lava-test-case', testcase_id, '--result', result]


def result_parser(xml_file):
    tree = ET.parse(xml_file)
    # dump test result xml to stdout for debug
    if debug_switcher is True:
        ET.dump(tree)
    root = tree.getroot()
    print 'There are ' + str(len(root.findall('TestPackage'))) + ' Test Packages in this test result file: ' + xml_file
    # testcase_counter = 0
    for elem in root.findall('Module'):
        # Naming: Package Name + Test Case Name + Test Name
        if 'abi' in elem.attrib.keys():
            package_name = '.'.join([elem.attrib['abi'], elem.attrib['name']])
        else:
            package_name = elem.attrib['name']
        tests_executed = len(elem.findall('.//Test'))
        tests_passed = len(elem.findall('.//Test[@result="pass"]'))
        tests_failed = len(elem.findall('.//Test[@result="fail"]'))
        subprocess.call(['lava-test-case', package_name + '_executed', '--result', 'pass', '--measurement', str(tests_executed)])
        subprocess.call(['lava-test-case', package_name + '_passed', '--result', 'pass', '--measurement', str(tests_passed)])
        failed_result = 'pass'
        if tests_failed > 0:
            failed_result = 'fail'
        subprocess.call(['lava-test-case', package_name + '_failed', '--result', failed_result, '--measurement', str(tests_failed)])
    # leave the below code for now as commented
    # might be used in future (unlikely)
    #    for testcase in elem.iter('TestCase'):
    #        testcase_name = testcase.attrib['name']
    #        for test in testcase.iter('Test'):
    #            testcase_counter = testcase_counter + 1
    #            test_name = test.attrib['name']
    #            testcase_id = '.'.join([package_name, testcase_name, test_name])
    #            result = test.attrib['result']
    #            collect_result(testcase_id, result)
    # print 'There are ' + str(testcase_counter) + ' test cases in this test result file: ' + xml_file

# download and extract the CTS zip package
ctsurl = sys.argv[1]
# ToDo this might fail and exit ungracefully
ctsfile = urllib.urlretrieve(ctsurl, ctsurl.split('/')[-1])
print "downloaded %s" % sys.argv[1]
print "unzipping %s" % ctsurl.split('/')[-1]
# ToDo this might fail and exit ungracefully
with zipfile.ZipFile(ctsurl.split('/')[-1]) as z:
    z.extractall()
z.close()
print "unzipped CTS package"
os.chmod('android-cts/tools/cts-tradefed', 0755)

target_device = sys.argv[2]
# receive user input from JSON file and run
cts_stdout = open(CTS_STDOUT, 'w')
command = 'android-cts/tools/cts-tradefed ' + ' '.join([str(para) for para in sys.argv[3:]])
print command
cts_logcat_out = open(CTS_LOGCAT, 'w')
cts_logcat_command = "adb logcat"
cts_logcat = subprocess.Popen(shlex.split(cts_logcat_command), stdout=cts_logcat_out)

if 'fvp' in open('/tmp/lava_multi_node_cache.txt').read():
    # On Fast Models, CTS test will exit abnormally when pipe used(Bug 1904), use
    # pexpect here as a work around.
    child = pexpect.spawn(command, logfile=cts_stdout)
    print 'Starting CTS %s test...' % command.split(' ')[4]
    print 'Start time: %s' % datetime.datetime.now()
    # Since fvp is slow, give it some time to start the test.
    time.sleep(120)
    # Send exit command to cts-tf shell, so that TF will exit when remaining
    # tests complete.
    try:
        if not child.expect('cts-tf >'):
            child.sendline('exit')
    except pexpect.TIMEOUT:
        subprocess.call(['lava-test-case', 'CTS-Command-Check', '--result', 'fail'])
        print 'Failed to launch CTS shell, exiting...'
        sys.exit(1)
    while child.isalive():
        # When expect([pexpect.EOF]) returns 0, isalive() will be set to Flase.
        fvp_adb_check = subprocess.Popen(['adb', '-s', target_device, 'shell', 'echo', 'OK'])
        if fvp_adb_check.wait() != 0:
            print 'Terminating CTS test as adb connection is lost'
            child.terminate(force=True)
            subprocess.call(['lava-test-case', 'CTS-Command-Check', '--result', 'fail'])
            break
        try:
            child.expect([pexpect.EOF], timeout=60)
        except pexpect.TIMEOUT:
            print '%s is running...' % command.split(' ')[4]
    print 'End time: %s' % datetime.datetime.now()
    cts_logcat.kill()
else:
    return_check = subprocess.Popen(shlex.split(command), stdout=cts_stdout)
    # start heartbeat process
    heartbeat = Heartbeat(target_device, [return_check, cts_logcat])
    heartbeat.daemon = True
    heartbeat.start()
    if return_check.wait() != 0:
        # even though the whole command may not run successfully, continue to submit the existing result anyway
        # add test case CTS-Command-Check to indicate this incident
        print 'CTS command: ' + command + ' run failed!'
        # collect_result(testcase_id='CTS-Command-Check', result='fail')
        subprocess.call(['lava-test-case', 'CTS-Command-Check', '--result', 'fail'])
    heartbeat.shutdown()

cts_logcat_out.close()
cts_stdout.close()

# compress then attach the CTS stdout file to LAVA bundle
with open(CTS_STDOUT, 'rb') as f_in, gzip.open(CTS_STDOUT + '.gz', 'wb') as f_out:
    shutil.copyfileobj(f_in, f_out)
with open(CTS_LOGCAT, 'rb') as f_in, gzip.open(CTS_LOGCAT + '.gz', 'wb') as f_out:
    shutil.copyfileobj(f_in, f_out)
subprocess.call(['lava-test-run-attach', CTS_STDOUT + '.gz'])
subprocess.call(['lava-test-run-attach', CTS_LOGCAT + '.gz'])

# locate and parse the test result
result_dir = 'android-cts/results'
test_result = 'test_result.xml'
if os.path.exists(result_dir) and os.path.isdir(result_dir):
    for root, dirs, files in os.walk(result_dir):
        for name in files:
            if name.endswith(".zip"):
                subprocess.call(['lava-test-run-attach', os.path.join(root, name)])
            if name == test_result:
                result_parser(xml_file=os.path.join(root, name))
# set exit code so LAVA can trust the results
sys.exit(0)
