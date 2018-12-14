#!/usr/bin/env python

import argparse
import datetime
import logging
import os
import pexpect
import shlex
import shutil
import subprocess
import sys
import time

import result_parser

sys.path.insert(0, '../../lib/')
import py_test_lib  # nopep8


OUTPUT = '%s/output' % os.getcwd()
RESULT_FILE = '%s/result.txt' % OUTPUT
TRADEFED_STDOUT = '%s/tradefed-stdout.txt' % OUTPUT
TRADEFED_LOGCAT = '%s/tradefed-logcat.txt' % OUTPUT
TEST_PARAMS = ''


parser = argparse.ArgumentParser()
parser.add_argument('-t', dest='TEST_PARAMS', required=True,
                    help="tradefed shell test parameters")
parser.add_argument('-p', dest='TEST_PATH', required=True,
                    help="path to tradefed package top directory")
parser.add_argument('-r', dest='RESULTS_FORMAT', required=False,
                    default=result_parser.TradefedResultParser.AGGREGATED,
                    choices=[result_parser.TradefedResultParser.AGGREGATED,
                             result_parser.TradefedResultParser.ATOMIC],
                    help="The format of the saved results. 'aggregated' means number of \
                    passed and failed tests are recorded for each module. 'atomic' means \
                    each test result is recorded separately")

# The total number of failed test cases to be printed for this job
# Print too much failures would cause the lava job timed out
# Default to not print any failures
parser.add_argument('-f', dest='FAILURES_PRINTED', type=int,
                    required=False, default=0,
                    help="Speciy the number of failed test cases to be\
                    printed, 0 means not print any failures.")

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
    os.environ["VTS_ROOT"] = os.getcwd()
    command = "android-vts/tools/vts-tradefed"
    prompt = "vts-tf >"

if command is None:
    logger.error("Not supported path: %s" % args.TEST_PATH)
    sys.exit(1)

vts_monitor_enabled = False
if command == 'android-vts/tools/vts-tradefed' and \
        os.path.exists('android-vts/testcases/vts/script/monitor-runner-output.py'):
    vts_monitor_enabled = True
    vts_run_details = open('{}/vts_run_details.txt'.format(OUTPUT), 'w')
    monitor_cmd = 'android-vts/testcases/vts/script/monitor-runner-output.py -m'
    monitor_vts_output = subprocess.Popen(shlex.split(monitor_cmd), stderr=subprocess.STDOUT, stdout=vts_run_details)

child = pexpect.spawn(command, logfile=tradefed_stdout, searchwindowsize=1024)
try:
    child.expect(prompt, timeout=60)
    child.sendline(args.TEST_PARAMS)
except pexpect.TIMEOUT:
    result = 'lunch-tf-shell fail'
    py_test_lib.add_result(RESULT_FILE, result)

fail_to_complete = False
while child.isalive():
    subprocess.call('echo')
    subprocess.call(['echo', '--- line break ---'])
    logger.info('Checking adb connectivity...')
    adb_command = "adb shell echo OK"
    adb_check = subprocess.Popen(shlex.split(adb_command))
    if adb_check.wait() != 0:
        logger.debug('adb connection lost! maybe device is rebooting. Lets check again in 5 minute')
        time.sleep(300)
        adb_check = subprocess.Popen(shlex.split(adb_command))
        if adb_check.wait() != 0:
            logger.debug('adb connection lost! Trying to dump logs of all invocations...')
            child.sendline('d l')
            time.sleep(30)
            subprocess.call(['sh', '-c', '. ../../lib/sh-test-lib && . ../../lib/android-test-lib && adb_debug_info'])
            logger.debug('"adb devices" output')
            subprocess.call(['adb', 'devices'])
            logger.error('adb connection lost!! Will wait for 5 minutes and terminating tradefed shell test as adb connection is lost!')
            time.sleep(300)
            child.terminate(force=True)
            result = 'check-adb-connectivity fail'
            py_test_lib.add_result(RESULT_FILE, result)
            break
    else:
        logger.info('adb device is alive')
        time.sleep(300)

    # Check if all tests finished every minute.
    m = child.expect(['ResultReporter: Full Result:',
                      'ConsoleReporter:.*Test run failed to complete.',
                      pexpect.TIMEOUT],
                     searchwindowsize=1024,
                     timeout=60)
    # Once all tests finshed, exit from tf shell to throw EOF, which sets child.isalive() to false.
    if m == 0:
        try:
            child.expect(prompt, searchwindowsize=1024, timeout=60)
            logger.debug('Sending "exit" command to TF shell...')
            child.sendline('exit')
            child.expect(pexpect.EOF, timeout=60)
            logger.debug('Child process ended properly.')
        except pexpect.TIMEOUT as e:
            print(e)
            logger.debug('Unsuccessful clean exit, force killing child process...')
            child.terminate(force=True)
            break
    # Mark test run as fail when a module or the whole run failed to complete.
    elif m == 1:
        fail_to_complete = True
    # CTS not finished yet, continue to wait.
    elif m == 2:
        # Flush pexpect input buffer.
        child.expect(['.+', pexpect.TIMEOUT, pexpect.EOF], timeout=1)
        logger.info('Printing tradefed recent output...')
        subprocess.call(['tail', TRADEFED_STDOUT])

if fail_to_complete:
    py_test_lib.add_result(RESULT_FILE, 'tradefed-test-run fail')
else:
    py_test_lib.add_result(RESULT_FILE, 'tradefed-test-run pass')

logger.info('Tradefed test finished')
tradefed_logcat.kill()
tradefed_logcat_out.close()
tradefed_stdout.close()
if vts_monitor_enabled:
    monitor_vts_output.kill()
    vts_run_details.close()

# Locate and parse test result.
result_dir = '%s/results' % args.TEST_PATH
parser = result_parser.TradefedResultParser(RESULT_FILE)
parser.logger = logger
parser.results_format = args.RESULTS_FORMAT
parser.failures_to_print = args.FAILURES_PRINTED
success = parser.parse_recursively(result_dir)
sys.exit(0 if success else 1)
