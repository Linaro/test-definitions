#!/usr/bin/env python

import datetime
import os
import sys
import shlex
import shutil
import subprocess
import xml.etree.ElementTree as ET
import pexpect
import argparse
import logging

sys.path.insert(0, '../../lib/')
import py_test_lib  # nopep8


def result_parser(xml_file):
    try:
        tree = ET.parse(xml_file)
    except ET.ParseError as e:
        logger.error('xml.etree.ElementTree.ParseError: %s' % e)
        logger.info('Please Check %s manually' % xml_file)
        sys.exit(1)
    root = tree.getroot()
    logger.info('Test modules in %s: %s'
                % (xml_file, str(len(root.findall('Module')))))
    for elem in root.findall('Module'):
        # Naming: Module Name + Test Case Name + Test Name
        if 'abi' in elem.attrib.keys():
            module_name = '.'.join([elem.attrib['abi'], elem.attrib['name']])
        else:
            module_name = elem.attrib['name']

        tests_executed = len(elem.findall('.//Test'))
        tests_passed = len(elem.findall('.//Test[@result="pass"]'))
        tests_failed = len(elem.findall('.//Test[@result="fail"]'))

        result = '%s_executed pass %s' % (module_name, str(tests_executed))
        py_test_lib.add_result(RESULT_FILE, result)

        result = '%s_passed pass %s' % (module_name, str(tests_passed))
        py_test_lib.add_result(RESULT_FILE, result)

        failed_result = 'pass'
        if tests_failed > 0:
            failed_result = 'fail'
        result = '%s_failed %s %s' % (module_name, failed_result,
                                      str(tests_failed))
        py_test_lib.add_result(RESULT_FILE, result)


OUTPUT = '%s/output' % os.getcwd()
RESULT_FILE = '%s/result.txt' % OUTPUT
CTS_STDOUT = '%s/cts-stdout.txt' % OUTPUT
CTS_LOGCAT = '%s/cts-logcat.txt' % OUTPUT
TEST_PARAMS = ''
SN = ''

parser = argparse.ArgumentParser()
parser.add_argument('-t', dest='TEST_PARAMS', required=True,
                    help="cts test parameters")
parser.add_argument('-n', dest='SN', required=True,
                    help='Target device serial no.')
args = parser.parse_args()
TEST_PARAMS = args.TEST_PARAMS
SN = args.SN

if os.path.exists(OUTPUT):
    suffix = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    shutil.move(OUTPUT, '%s_%s' % (OUTPUT, suffix))
os.makedirs(OUTPUT)

# Setup logger.
# There might be an issue in lava/local dispatcher, most likely problem of
# pexpect. It prints the messages from print() last, not by sequence.
# Use logging and subprocess.call() to work around this.
logger = logging.getLogger('CTS')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(name)s: %(levelname)s: %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

cts_stdout = open(CTS_STDOUT, 'w')
cts_logcat_out = open(CTS_LOGCAT, 'w')
cts_logcat = subprocess.Popen(['adb', 'logcat'], stdout=cts_logcat_out)

logger.info('Test params: %s' % TEST_PARAMS)
logger.info('Starting CTS test...')

child = pexpect.spawn('android-cts/tools/cts-tradefed', logfile=cts_stdout)
try:
    child.expect('cts-tf >', timeout=60)
    child.sendline(TEST_PARAMS)
except pexpect.TIMEOUT:
    result = 'lunch-cts-rf-shell fail'
    py_test_lib.add_result(RESULT_FILE, result)

while child.isalive():
    subprocess.call('echo')
    subprocess.call(['echo', '--- line break ---'])
    logger.info('Checking adb connectivity...')
    adb_command = "adb -s %s shell echo OK" % SN
    adb_check = subprocess.Popen(shlex.split(adb_command))
    if adb_check.wait() != 0:
        subprocess.call(['adb', 'devices'])
        logger.error('Terminating CTS test as adb connection is lost!')
        child.terminate(force=True)
        result = 'check-adb-connectivity fail'
        py_test_lib.add_result(RESULT_FILE, result)
        break
    else:
        logger.info('adb device is alive')

    try:
        # Check if all tests finished every minute.
        child.expect('I/ResultReporter: Full Result:', timeout=60)
        # Once all tests finshed, exit from tf shell and throw EOF.
        child.sendline('exit')
        child.expect(pexpect.EOF, timeout=60)
    except pexpect.TIMEOUT:
        logger.info('Printing cts recent output...')
        subprocess.call(['tail', CTS_STDOUT])

logger.info('CTS test finished')
cts_logcat.kill()
cts_logcat_out.close()
cts_stdout.close()

# Locate and parse test result.
result_dir = 'android-cts/results'
test_result = 'test_result.xml'
if os.path.exists(result_dir) and os.path.isdir(result_dir):
    for root, dirs, files in os.walk(result_dir):
        for name in files:
            if name == test_result:
                result_parser(xml_file=os.path.join(root, name))
