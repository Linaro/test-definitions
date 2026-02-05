#!/usr/bin/env python3

import argparse
import datetime
import logging
import os
import pexpect
import re
import subprocess
import sys
import time

sys.path.insert(0, "../../../lib/")
sys.path.insert(1, "../../")
import py_test_lib  # nopep8
from py_util_lib import call_shell_lib  # nopep8
import tradefed.result_parser as result_parser  # nopep8
from multinode.tradefed.utils import *  # nopep8
from multinode.tradefed.sts_util import StsUtil  # nopep8

OUTPUT = "%s/output" % os.getcwd()
RESULT_FILE = "%s/result.txt" % OUTPUT
TRADEFED_STDOUT = "%s/tradefed-stdout.txt" % OUTPUT
TRADEFED_LOGCAT = "%s/tradefed-logcat-%s.txt" % (OUTPUT, "%s")


parser = argparse.ArgumentParser()
parser.add_argument(
    "-t", dest="TEST_PARAMS", required=True, help="TradeFed shell test parameters"
)
parser.add_argument(
    "-u",
    dest="TEST_RETRY_PARAMS",
    required=False,
    help="TradeFed shell test parameters for TradeFed session retry",
)
parser.add_argument(
    "-i",
    dest="MAX_NUM_RUNS",
    required=False,
    default=10,
    type=int,
    help="Maximum number of TradeFed runs. Based on the first run, retries can be \
                    triggered to stabilize the results of the test suite.",
)
parser.add_argument(
    "-n",
    dest="RUNS_IF_UNCHANGED",
    required=False,
    default=3,
    type=int,
    help="Number of runs while the number of failures and completed modules does \
                    not change. Results are considered to be stable after this number of runs.",
)
parser.add_argument(
    "-p", dest="TEST_PATH", required=True, help="path to TradeFed package top directory"
)
parser.add_argument(
    "-s",
    dest="STATE_CHECK_FREQUENCY_SECS",
    required=False,
    default=60,
    type=int,
    help="Every STATE_CHECK_FREQUENCY_SECS seconds, the state of connected devices is \
                    checked and the last few lines TradeFed output are printed. Increase this time \
                    for large test suite runs to reduce the noise in the LAVA logs.",
)
parser.add_argument(
    "-r",
    dest="RESULTS_FORMAT",
    required=False,
    default=result_parser.TradefedResultParser.AGGREGATED,
    choices=[
        result_parser.TradefedResultParser.AGGREGATED,
        result_parser.TradefedResultParser.ATOMIC,
    ],
    help="The format of the saved results. 'aggregated' means number of \
                    passed and failed tests are recorded for each module. 'atomic' means \
                    each test result is recorded separately",
)
parser.add_argument(
    "-m",
    dest="DEVICE_WORKER_MAPPING_FILE",
    required=True,
    help='File listing adb devices to be used for testing. For devices connected \
                    via adb TCP/IP, the LAVA worker job id should be given as second column, \
                    separated by semicolon. Individual lines in that files will look like \
                    "some_device_serial" or "some_device_ip;worker_host_id"',
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
    help="Specify the number of failed test cases to be\
                    printed, 0 means not print any failures.",
)
parser.add_argument(
    "--userdata_image_file",
    dest="USERDATA_IMAGE_FILE",
    required=False,
    help="Userdata image file that will be \
                    used to reset devices to a clean state before starting \
                    TradeFed reruns.",
)

args = parser.parse_args()

if os.path.exists(OUTPUT):
    suffix = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    shutil.move(OUTPUT, "%s_%s" % (OUTPUT, suffix))
os.makedirs(OUTPUT)

# Setup logger.
# There might be an issue in lava/local dispatcher, most likely problem of
# pexpect. It prints the messages from print() last, not by sequence.
# Use logging and subprocess.run() to work around this.
logger = logging.getLogger("TradefedRunnerMultinode")
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter("%(asctime)s - %(name)s: %(levelname)s: %(message)s")
ch.setFormatter(formatter)
logger.addHandler(ch)

devices = []
try:
    with open(args.DEVICE_WORKER_MAPPING_FILE) as mappingFile:
        for line in filter(None, (line.rstrip() for line in mappingFile)):
            deviceToWorker = line.split(sep=";")
            device_address = deviceToWorker[0]
            worker_job_id = (
                None
                if (len(deviceToWorker) == 1 or not deviceToWorker[1])
                else deviceToWorker[1]
            )
            devices.append(
                Device(
                    serial_or_address=device_address,
                    logcat_output_filename=TRADEFED_LOGCAT % device_address,
                    worker_job_id=worker_job_id,
                    userdata_image_file=args.USERDATA_IMAGE_FILE,
                )
            )
except OSError as e:
    logger.error("Mapping file cannot be opened: %s" % args.DEVICE_WORKER_MAPPING_FILE)
    sys.exit(1)

logger.info("Configured devices:")
for device in devices:
    if device.worker_job_id is None:
        logger.info("%s (locally connected via USB)" % device.serial_or_address)
    else:
        logger.info(
            "%s (remote worker job id: %s)"
            % (device.serial_or_address, device.worker_job_id)
        )


def release_all_devices():
    for device in devices:
        device.release()


def cleanup_and_exit(exit_code=0, message=None):
    if message:
        logger.error(message)
    release_all_devices()
    sys.exit(exit_code)


tradefed_stdout = open(TRADEFED_STDOUT, "w")

logger.info("Test params: %s" % args.TEST_PARAMS)
logger.info("Starting TradeFed shell and waiting for device detection...")

command = None
prompt = None
results_heading_re = None
results_line_re = None
valid_test_paths = ["android-cts", "android-gts", "android-sts"]
if args.TEST_PATH in valid_test_paths:
    suite = args.TEST_PATH[-3:]
    command = "android-%s/tools/%s-tradefed" % (suite, suite)
    prompt = "%s-tf >" % suite
    results_heading_re = re.compile(
        r"Session\s+Pass\s+Fail\s+Modules\s+Complete\s+Result Directory\s+Test Plan\s+Device serial\(s\)\s+Build ID\s+Product"
    )
    results_line_re_without_session = r"\s+(\d+\s+){3,3}(of)\s+\d+\s+"

if command is None:
    cleanup_and_exit(1, "Not supported path: %s" % args.TEST_PATH)

if args.TEST_PATH == "android-sts":
    stsUtil = StsUtil(devices[0].serial_or_address, logger)

# Locate and parse test result.
result_dir_parent = os.path.join(args.TEST_PATH, "results")


def last_result_dir():
    latest_subdir = next(
        reversed(
            sorted(
                [
                    d
                    for d in os.listdir(result_dir_parent)
                    if os.path.isdir(os.path.join(result_dir_parent, d))
                ]
            )
        )
    )

    return os.path.join(result_dir_parent, latest_subdir)


device_detected_re = re.compile(r"DeviceManager: Detected new device ")
device_detected_search_re = re.compile(
    r"DeviceManager: Detected new device .*$", flags=re.M
)
tradefed_start_retry_count = 5
all_devices_names = set(device.serial_or_address for device in devices)
for tradefed_start_retry in range(tradefed_start_retry_count):
    child = pexpect.spawnu(command, logfile=tradefed_stdout)
    try:
        devices_to_detect = all_devices_names.copy()
        while devices_to_detect:
            # Find and parse output lines following this pattern:
            # 04-23 12:30:33 I/DeviceManager: Detected new device serial_or_address
            child.expect(device_detected_re, timeout=30)
            output_lines = subprocess.check_output(["tail", TRADEFED_STDOUT]).decode(
                "utf-8"
            )
            matches = [
                match[1].strip()
                for match in (
                    device_detected_re.split(line_match)
                    for line_match in device_detected_search_re.findall(output_lines)
                )
                if len(match) == 2 and match[1]
            ]
            for match in matches:
                try:
                    devices_to_detect.remove(match)
                except KeyError:
                    if match not in all_devices_names:
                        logger.debug("Unexpected device detected: %s" % match)

    except (pexpect.TIMEOUT, pexpect.EOF) as e:
        logger.warning(
            "TradeFed did not detect all devices. Checking device availability and restarting TradeFed..."
        )
        print(e)
        child.terminate(force=True)
        missing_devices = [
            device
            for device in devices
            if device.serial_or_address in devices_to_detect
        ]
        for device in missing_devices:
            if not device.ensure_available(logger=logger):
                cleanup_and_exit(
                    1,
                    "adb device %s is not available and reconnection attempts failed. Aborting."
                    % device.serial_or_address,
                )

if devices_to_detect:
    cleanup_and_exit(
        1,
        "TradeFed did not detect all available devices after %s retries. Aborting."
        % tradefed_start_retry_count,
    )

logger.info("Starting TradeFed shell test.")
try:
    child.expect(prompt, timeout=60)
    child.sendline(args.TEST_PARAMS)
except pexpect.TIMEOUT:
    result = "lunch-tf-shell fail"
    py_test_lib.add_result(RESULT_FILE, result)

retry_check = RetryCheck(args.MAX_NUM_RUNS, args.RUNS_IF_UNCHANGED)

# Loop while TradeFed is running.
# This loop will rerun TradeFed if requested, until the number of failures stabilizes or a maximum
# number of retries is reached.
# Meanwhile, try to keep all devices accessible. For remote devices, use handshakes to inform remote
# workers that their locally connected device needs to be reset.
# The worker host side of the LAVA MultiNode messages is implemented in
# wait-and-keep-local-device-accessible.yaml
fail_to_complete = False
# Assuming TradeFed is started from a clean environment, the first run will have the id 0
# Each retry gets a new session id.
tradefed_session_id = 0
result_summary = None
while child.isalive():
    subprocess.run("echo")
    subprocess.run(["echo", "--- line break ---"])
    logger.info("Checking adb connectivity...")
    for device in devices:
        device.ensure_available(logger=logger)
    num_available_devices = sum(device.is_available() for device in devices)
    if num_available_devices < len(devices):
        logger.debug("Some devices are lost. Dumping state of adb/USB devices.")
        child.sendline("dump logs")

        call_shell_lib("adb_debug_info")
        logger.debug('"adb devices" output')
        subprocess.run(["adb", "devices"])

        if num_available_devices == 0:
            logger.error(
                "adb connection to all devices lost!! Will wait for 5 minutes and "
                "terminating TradeFed shell test!"
            )
            time.sleep(300)
            child.terminate(force=True)
            result = "check-adb-connectivity fail"
            py_test_lib.add_result(RESULT_FILE, result)
            fail_to_complete = True
            break

    logger.info(
        "Currently available devices: %s"
        % [device.serial_or_address for device in devices if device.is_available()]
    )

    # Check if all tests finished every minute.
    m = child.expect(
        [
            "ResultReporter: Full Result:",
            "ConsoleReporter:.*Test run failed to complete.",
            pexpect.TIMEOUT,
        ],
        timeout=args.STATE_CHECK_FREQUENCY_SECS,
    )

    # TradeFed run not finished yet, continue to wait.
    if m == 2:
        # Flush pexpect input buffer.
        child.expect([".+", pexpect.TIMEOUT, pexpect.EOF], timeout=1)
        logger.info("Printing tradefed recent output...")
        subprocess.run(["tail", TRADEFED_STDOUT])
        continue

    # A module or test run failed to complete. This is a case for TradeFed retry
    if m == 1:
        fail_to_complete = True
        logger.warning("TradeFed reported failure to complete a module.")
        # TradeFed didn't report completion yet, so keep going.
        continue

    assert m == 0

    # All tests finished. Check if rerunning is necessary/sensible.
    # Once all tests and reruns finished, exit from TradeFed shell to throw EOF,
    # which sets child.isalive() to false.
    try:
        logger.debug("Checking TradeFed session result...")
        child.expect(prompt, timeout=60)
        child.sendline("list results")
        child.expect(results_heading_re, timeout=60)
        results_line_re = re.compile(
            "(%s)%s"
            % (
                str(tradefed_session_id),  # Expect the current session ID in the output
                results_line_re_without_session,
            )
        )
        child.expect(results_line_re, timeout=60)
        output_lines = subprocess.check_output(["tail", TRADEFED_STDOUT])
        output_lines_match = results_line_re.search(str(output_lines))
        if output_lines_match is None:
            cleanup_and_exit(
                1,
                "Unexpected TradeFed output. Could not find expected results line for the current "
                "TradeFed session (%s)" % str(tradefed_session_id),
            )
        # Expected column contents: see results_heading_re
        result_line_columns = re.split(r"\s+", output_lines_match.group())
        pass_count = result_line_columns[1]
        failure_count = result_line_columns[2]
        modules_completed = result_line_columns[3]
        modules_total = result_line_columns[5]
        timestamp = result_line_columns[6]
        result_summary = ResultSummary(
            failure_count, modules_completed, modules_total, timestamp
        )
        retry_check.post_result(result_summary)
        logger.info(
            "Finished TradeFed session %s. %s of %s modules completed with %s passed "
            "tests and %s failures."
            % (
                tradefed_session_id,
                str(modules_completed),
                str(modules_total),
                str(pass_count),
                str(failure_count),
            )
        )
    except (pexpect.TIMEOUT, pexpect.EOF) as e:
        logger.error(
            "Unexpected TradeFed output/behavior while trying to fetch test run results. "
            "Printing the exception and killing the TradeFed process..."
        )
        print(e)
        child.terminate(force=True)
        fail_to_complete = True
        break

    # Preparing for rerunning or releasing results.
    # A workaround is required here for STS; It patches the device fingerprint
    # that is stored in the result files, to make it look like a 'user' build
    # with 'release-keys'.
    # That actually breaks the TradeFed retry feature, as the stored fingerprint
    # won't match anymore with the fingerprint reported by the device.
    if suite == "sts":
        try:
            stsUtil.fix_result_file_fingerprints(last_result_dir())
        except subprocess.CalledProcessError as e:
            fail_to_complete = True
            print(e)
            logger.error(
                "Could not apply workarounds for STS due to an "
                "adb-related error. Cannot continue with TradeFed "
                "reruns; results might be incomplete."
            )
            child.terminate(force=True)
            break

    # Retry if necessary and applicable.
    # NOTE: both checks here should be equivalent, but checking both of them might make the TradeFed
    # output parsing more reliable.
    if not result_summary.was_successful() or fail_to_complete:
        if args.TEST_RETRY_PARAMS is None:
            logger.debug(
                "NOT retrying TradeFed session as TEST_RETRY_PARAMS is not defined."
            )
        elif not retry_check.should_continue():
            logger.info(
                "NOT retrying TradeFed session as maximum number of retries is reached."
            )
        else:
            logger.info("Retrying with results of session %s" % tradefed_session_id)
            logger.info("First resetting the devices to a clean state...")

            unavailable_devices = []
            for device in devices:
                if not device.userdata_reset():
                    unavailable_devices += [device.serial_or_address]
            if unavailable_devices:
                logger.warning(
                    "Following devices were not reset successfully "
                    "or are not yet available again: %s"
                    % ", ".join(unavailable_devices)
                )

            try:
                child.expect(prompt, timeout=60)
                child.sendline(
                    "%s --retry %s" % (args.TEST_RETRY_PARAMS, str(tradefed_session_id))
                )
                tradefed_session_id += 1
                fail_to_complete = False  # Reset as we have a new chance to complete.
            except pexpect.TIMEOUT:
                print(e)
                logger.error(
                    "Timeout while starting a TradeFed retry. Force killing the child process..."
                )
                child.terminate(force=True)
                fail_to_complete = True
                break
            continue

    try:
        child.expect(prompt, timeout=60)
        logger.debug('Sending "exit" command to TF shell...')
        child.sendline("exit")
        child.expect(pexpect.EOF, timeout=60)
        logger.debug("Child process ended properly.")
    except pexpect.TIMEOUT as e:
        # The Tradefed shell is hanging longer than expected for some reason.
        # We need to kill it, but that most likely doesn't affect the results of
        # previously finished test runs, so don't report failure.
        print(e)
        logger.debug(
            "Timeout while trying to exit cleanly, force killing child process..."
        )
        child.terminate(force=True)
        break

tradefed_stdout.close()

if fail_to_complete:
    py_test_lib.add_result(RESULT_FILE, "tradefed-test-run fail")
else:
    py_test_lib.add_result(RESULT_FILE, "tradefed-test-run pass")

logger.info("Tradefed test finished")

# Log only results of the last run. It also lists all successful tests from previous runs.
parser = result_parser.TradefedResultParser(RESULT_FILE)
parser.logger = logger
parser.results_format = args.RESULTS_FORMAT
parser.failures_to_print = args.FAILURES_PRINTED
parser_success = parser.parse_recursively(last_result_dir())
if not parser_success:
    logger.warning(
        "Failed to parse the TradeFed logs. Test result listing in the LAVA "
        "logs will be incomplete."
    )

# Report failure if not all test modules were completed, if the test result
# files seem broken or incomplete or if Tradefed ran into a unknown state.
summary_complete = result_summary.all_modules_completed() if result_summary else False
success = parser_success and not fail_to_complete and summary_complete

cleanup_and_exit(0 if success else 1)
