#!/usr/bin/env python

import datetime
import os
import re
import sys
import shlex
import shutil
import subprocess
import xml.etree.ElementTree as ET
import argparse
import logging
import time

sys.path.insert(0, "../../lib/")
import py_test_lib  # nopep8


OUTPUT = "%s/output" % os.getcwd()
RESULT_FILE = "%s/result.txt" % OUTPUT
TRADEFED_STDOUT = "%s/tradefed-stdout.txt" % OUTPUT
TRADEFED_LOGCAT = "%s/tradefed-logcat.txt" % OUTPUT
TEST_PARAMS = ""
AGGREGATED = "aggregated"
ATOMIC = "atomic"


def result_parser(xml_file, result_format):
    etree_file = open(xml_file, "rb")
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
        if not (
            num in (0x9, 0xA, 0xD)
            or 0x20 <= num <= 0xD7FF
            or 0xE000 <= num <= 0xFFFD
            or 0x10000 <= num <= 0x10FFFF
        ):
            etree_content = etree_content[:mstart] + etree_content[mend:]
            endpos = len(etree_content)
            # next time search again from the same position as this time
            # as the detected pattern was removed here
            pos = mstart
        else:
            # continue from the end of this match
            pos = mend

    try:
        root = ET.fromstring(etree_content)
    except ET.ParseError as e:
        logger.error("xml.etree.ElementTree.ParseError: %s" % e)
        logger.info("Please Check %s manually" % xml_file)
        sys.exit(1)
    logger.info("Test modules in %s: %s" % (xml_file, str(len(root.findall("Module")))))
    failures_count = 0
    for elem in root.findall("Module"):
        # Naming: Module Name + Test Case Name + Test Name
        if "abi" in elem.attrib.keys():
            module_name = ".".join([elem.attrib["abi"], elem.attrib["name"]])
        else:
            module_name = elem.attrib["name"]

        if result_format == AGGREGATED:
            tests_executed = len(elem.findall(".//Test"))
            tests_passed = len(elem.findall('.//Test[@result="pass"]'))
            tests_failed = len(elem.findall('.//Test[@result="fail"]'))

            result = "%s_executed pass %s" % (module_name, str(tests_executed))
            py_test_lib.add_result(RESULT_FILE, result)

            result = "%s_passed pass %s" % (module_name, str(tests_passed))
            py_test_lib.add_result(RESULT_FILE, result)

            failed_result = "pass"
            if tests_failed > 0:
                failed_result = "fail"
            result = "%s_failed %s %s" % (module_name, failed_result, str(tests_failed))
            py_test_lib.add_result(RESULT_FILE, result)

            # output result to show if the module is done or not
            tests_done = elem.get("done", "false")
            if tests_done == "false":
                result = "%s_done fail" % module_name
            else:
                result = "%s_done pass" % module_name
            py_test_lib.add_result(RESULT_FILE, result)

            if args.FAILURES_PRINTED > 0 and failures_count < args.FAILURES_PRINTED:
                # print failed test cases for debug
                test_cases = elem.findall(".//TestCase")
                for test_case in test_cases:
                    failed_tests = test_case.findall('.//Test[@result="fail"]')
                    for failed_test in failed_tests:
                        test_name = "%s/%s.%s" % (
                            module_name,
                            test_case.get("name"),
                            failed_test.get("name"),
                        )
                        failures = failed_test.findall(".//Failure")
                        failure_msg = ""
                        for failure in failures:
                            failure_msg = "%s \n %s" % (
                                failure_msg,
                                failure.get("message"),
                            )

                        logger.info("%s %s" % (test_name, failure_msg.strip()))
                        failures_count = failures_count + 1
                        if failures_count > args.FAILURES_PRINTED:
                            logger.info(
                                "There are more than %d test cases "
                                "failed, the output for the rest "
                                "failed test cases will be "
                                "skipped." % (args.FAILURES_PRINTED)
                            )
                            # break the for loop of failed_tests
                            break
                    if failures_count > args.FAILURES_PRINTED:
                        # break the for loop of test_cases
                        break

        if result_format == ATOMIC:
            test_cases = elem.findall(".//TestCase")
            for test_case in test_cases:
                tests = test_case.findall(".//Test")
                for atomic_test in tests:
                    atomic_test_result = atomic_test.get("result")
                    atomic_test_name = "%s/%s.%s" % (
                        module_name,
                        test_case.get("name"),
                        atomic_test.get("name"),
                    )
                    py_test_lib.add_result(
                        RESULT_FILE, "%s %s" % (atomic_test_name, atomic_test_result)
                    )


parser = argparse.ArgumentParser()
parser.add_argument(
    "-t", dest="TEST_PARAMS", required=True, help="tradefed shell test parameters"
)
parser.add_argument(
    "-p", dest="TEST_PATH", required=True, help="path to tradefed package top directory"
)
parser.add_argument(
    "-r",
    dest="RESULTS_FORMAT",
    required=False,
    default=AGGREGATED,
    choices=[AGGREGATED, ATOMIC],
    help="The format of the saved results. 'aggregated' means number of \
                    passed and failed tests are recorded for each module. 'atomic' means \
                    each test result is recorded separately",
)

# The total number of failed test cases to be printed for this job
# Print too much failures would cause the lava job timed out
# Default to not print any failures
parser.add_argument(
    "-f",
    dest="FAILURES_PRINTED",
    type=int,
    required=False,
    default=0,
    help="Speciy the number of failed test cases to be\
                    printed, 0 means not print any failures.",
)

args = parser.parse_args()
# TEST_PARAMS = args.TEST_PARAMS

if os.path.exists(OUTPUT):
    suffix = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    shutil.move(OUTPUT, "%s_%s" % (OUTPUT, suffix))
os.makedirs(OUTPUT)

# Setup logger.
# There might be an issue in lava/local dispatcher, most likely problem of
# pexpect. It prints the messages from print() last, not by sequence.
# Use logging and subprocess.call() to work around this.
logger = logging.getLogger("Tradefed")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter("%(asctime)s - %(name)s: %(levelname)s: %(message)s")
ch.setFormatter(formatter)
logger.addHandler(ch)

tradefed_stdout = open(TRADEFED_STDOUT, "w")
tradefed_logcat_out = open(TRADEFED_LOGCAT, "w")
tradefed_logcat = subprocess.Popen(["adb", "logcat"], stdout=tradefed_logcat_out)

logger.info("Test params: %s" % args.TEST_PARAMS)
logger.info("Starting tradefed shell test...")

command = None
prompt = None
if args.TEST_PATH == "android-cts":
    command = "android-cts/tools/cts-tradefed run commandAndExit " + args.TEST_PARAMS
if args.TEST_PATH == "android-vts":
    os.environ["VTS_ROOT"] = os.getcwd()
    command = "android-vts/tools/vts-tradefed run commandAndExit " + args.TEST_PARAMS

if command is None:
    logger.error("Not supported path: %s" % args.TEST_PATH)
    sys.exit(1)

child = subprocess.Popen(
    shlex.split(command), stderr=subprocess.STDOUT, stdout=tradefed_stdout
)
fail_to_complete = child.wait()

if fail_to_complete:
    py_test_lib.add_result(RESULT_FILE, "tradefed-test-run fail")
else:
    py_test_lib.add_result(RESULT_FILE, "tradefed-test-run pass")

logger.info("Tradefed test finished")
tradefed_stdout.close()
tradefed_logcat.kill()
tradefed_logcat_out.close()

# Locate and parse test result.
result_dir = "%s/results" % args.TEST_PATH
test_result = "test_result.xml"
if os.path.exists(result_dir) and os.path.isdir(result_dir):
    for root, dirs, files in os.walk(result_dir):
        for name in files:
            if name == test_result:
                result_parser(os.path.join(root, name), args.RESULTS_FORMAT)
