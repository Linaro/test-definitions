#!/usr/bin/env python

import datetime
import os
import re
import sys
import shlex
import shutil
import subprocess
import xml.etree.ElementTree as ET
import pexpect
import argparse
import logging
import time

sys.path.insert(0, '../../lib/')
import py_test_lib  # nopep8


OUTPUT = '%s/output' % os.getcwd()
RESULT_FILE = '%s/result.txt' % OUTPUT
TRADEFED_STDOUT = '%s/tradefed-stdout.txt' % OUTPUT
TRADEFED_LOGCAT = '%s/tradefed-logcat.txt' % OUTPUT
TEST_PARAMS = ''
AGGREGATED = 'aggregated'
ATOMIC = 'atomic'


def result_parser(xml_file, result_format):
    etree_file = open(xml_file, 'rb')
    etree_content = etree_file.read()
    rx = re.compile("&#([0-9]+);|&#x([0-9a-fA-F]+);")
    endpos = len(etree_content)
    pos = 0
    while pos < endpos:
        # remove characters that don't conform to XML spec
        m = rx.search(etree_content, pos)
        if not m:
            break
        mstart, mend = m.span()
        target = m.group(1)
        if target:
            num = int(target)
        else:
            num = int(m.group(2), 16)
        # #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]
        if not(num in (0x9, 0xA, 0xD) or
                0x20 <= num <= 0xD7FF or
                0xE000 <= num <= 0xFFFD or
                0x10000 <= num <= 0x10FFFF):
            etree_content = etree_content[:mstart] + etree_content[mend:]
            endpos = len(etree_content)
        pos = mend

    try:
        root = ET.fromstring(etree_content)
    except ET.ParseError as e:
        logger.error('xml.etree.ElementTree.ParseError: %s' % e)
        logger.info('Please Check %s manually' % xml_file)
        sys.exit(1)
    logger.info('Test modules in %s: %s'
                % (xml_file, str(len(root.findall('Module')))))
    for elem in root.findall('Module'):
        # Naming: Module Name + Test Case Name + Test Name
        if 'abi' in elem.attrib.keys():
            module_name = '.'.join([elem.attrib['abi'], elem.attrib['name']])
        else:
            module_name = elem.attrib['name']

        if result_format == AGGREGATED:
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

        if result_format == ATOMIC:
            test_cases = elem.findall('.//TestCase')
            for test_case in test_cases:
                tests = test_case.findall('.//Test')
                for atomic_test in tests:
                    atomic_test_result = atomic_test.get("result")
                    atomic_test_name = "%s/%s.%s" % (module_name,
                                                     test_case.get("name"),
                                                     atomic_test.get("name"))
                    py_test_lib.add_result(
                        RESULT_FILE, "%s %s" % (atomic_test_name,
                                                atomic_test_result))


parser = argparse.ArgumentParser()
parser.add_argument('-t', dest='TEST_PARAMS', required=True,
                    help="tradefed shell test parameters")
parser.add_argument('-p', dest='TEST_PATH', required=True,
                    help="path to tradefed package top directory")
parser.add_argument('-r', dest='RESULTS_FORMAT', required=False,
                    default=AGGREGATED, choices=[AGGREGATED, ATOMIC],
                    help="The format of the saved results. 'aggregated' means number of \
                    passed and failed tests are recorded for each module. 'atomic' means \
                    each test result is recorded separately")
args = parser.parse_args()
# TEST_PARAMS = args.TEST_PARAMS

if os.path.exists(OUTPUT):
    suffix = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
    shutil.move(OUTPUT, '%s_%s' % (OUTPUT, suffix))
os.makedirs(OUTPUT)

# Setup logger.
# There might be an issue in lava/local dispatcher, most likely problem of
# pexpect. It prints the messages from print() last, not by sequence.
# Use logging and subprocess.call() to work around this.
logger = logging.getLogger('Tradefed')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(name)s: %(levelname)s: %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

tradefed_stdout = open(TRADEFED_STDOUT, 'w')
tradefed_logcat_out = open(TRADEFED_LOGCAT, 'w')
tradefed_logcat = subprocess.Popen(['adb', 'logcat'], stdout=tradefed_logcat_out)

logger.info('Test params: %s' % args.TEST_PARAMS)
logger.info('Starting tradefed shell test...')

command = None
prompt = None
if args.TEST_PATH == "android-cts":
    command = "android-cts/tools/cts-tradefed"
    prompt = "cts-tf >"
if args.TEST_PATH == "android-vts":
    command = "android-vts/tools/vts-tradefed"
    prompt = "vts-tf >"

if command is None:
    logger.error("Not supported path: %s" % args.TEST_PATH)
    sys.exit(1)

child = pexpect.spawn(command, logfile=tradefed_stdout)
try:
    child.expect(prompt, timeout=60)
    child.sendline(args.TEST_PARAMS)
except pexpect.TIMEOUT:
    result = 'lunch-tf-shell fail'
    py_test_lib.add_result(RESULT_FILE, result)

while child.isalive():
    subprocess.call('echo')
    subprocess.call(['echo', '--- line break ---'])
    logger.info('Checking adb connectivity...')
    adb_command = "adb shell echo OK"
    adb_check = subprocess.Popen(shlex.split(adb_command))
    if adb_check.wait() != 0:
        subprocess.call(['adb', 'devices'])
        logger.error('adb connection lost!! Will wait for 5 minutes and terminating tradefed shell test as adb connection is lost!')
        time.sleep(300)
        child.terminate(force=True)
        result = 'check-adb-connectivity fail'
        py_test_lib.add_result(RESULT_FILE, result)
        break
    else:
        logger.info('adb device is alive')

    # Check if all tests finished every minute.
    m = child.expect(['I/ResultReporter: Full Result:',
                      'I/ConsoleReporter:.*Test run failed to complete.',
                      pexpect.TIMEOUT],
                     timeout=60)
    # CTS tests finished correctly.
    if m == 0:
        py_test_lib.add_result(RESULT_FILE, 'tradefed-test-run pass')
    # CTS tests ended with failure.
    elif m == 1:
        py_test_lib.add_result(RESULT_FILE, 'tradefed-test-run fail')
    # CTS not finished yet, continue to wait.
    elif m == 2:
        # Flush pexpect input buffer.
        child.expect(['.+', pexpect.TIMEOUT, pexpect.EOF], timeout=1)
        logger.info('Printing tradefed recent output...')
        subprocess.call(['tail', TRADEFED_STDOUT])

    # Once all tests finshed, exit from tf shell to throw EOF, which sets child.isalive() to false.
    if m == 0 or m == 1:
        child.sendline('exit')
        child.expect(pexpect.EOF, timeout=60)

logger.info('Tradefed test finished')
tradefed_logcat.kill()
tradefed_logcat_out.close()
tradefed_stdout.close()

# Locate and parse test result.
result_dir = '%s/results' % args.TEST_PATH
test_result = 'test_result.xml'
if os.path.exists(result_dir) and os.path.isdir(result_dir):
    for root, dirs, files in os.walk(result_dir):
        for name in files:
            if name == test_result:
                result_parser(os.path.join(root, name), args.RESULTS_FORMAT)
