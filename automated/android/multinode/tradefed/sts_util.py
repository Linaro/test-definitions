"""Utilities for handling STS-specific behavior in TradeFed.

The following behavior was noted at least in the 2018-09 version of STS for
Android 7. When running STS, it manipulates the logged device fingerprint to
show up as a 'user' build with 'release-keys', even when using the required
setup with either 'userdebug' or 'eng' build. That behavior breaks the TradeFed
rerun feature, as the fingerprint read from the device will not match the logged
fingerprint of a previous run.

StsUtil works around this behavior by reverting the manipulated fingerprint in
the log file to the string reported by the device. tradefed-runner-multinode.py
uses this module to apply STS workarounds automatically when STS is run.
"""

import os
import shutil
import subprocess
import xml.etree.ElementTree as ET


class StsUtil:
    """Interface for STS related workarounds when automating TradeFed.

    For applying StsUtil, use one instance per TradeFed STS invocation. Ideally,
    construct it before running any tests, so when the passed device is in a
    good known state. Call fix_result_file_fingerprints() after each completed
    run, before rerunning.

    Applying StsUtil to non-STS TradeFed runs does not help, but should also not
    affect the results in any way.
    """

    def __init__(self, device_serial_or_address, logger, device_access_timeout_secs=60):
        """Construct a StsUtil instance for a TradeFed invocation.

        Args:
            device_serial_or_address (str):
                Serial number of network address if the device that will be used
                to determine the reference fingerprint.
            logger (logging.Logger)
                Logger instance to redirect messages to.
            device_access_timeout_secs (int):
                Timeout in seconds for `adb` calls.
        """

        self.device_serial_or_address = device_serial_or_address
        self.logger = logger
        self.device_access_timeout_secs = device_access_timeout_secs
        # Try reading the device fingerprint now. There is a better chance that
        # the device is in a good state now than after a test run. If reading
        # fails here, however, we can still retry in
        # fix_result_file_fingerprints().
        try:
            self.device_fingerprint = self.read_device_fingerprint()
        except subprocess.CalledProcessError:
            self.device_fingerprint = None

    def read_device_fingerprint(self):
        """Read the fingerprint of device_serial_or_address via adb.

        Returns:
            str:
                Fingerprint of the device.

        Raises:
            subprocess.CalledProcessError:
                If the communication with `adb` does not lead to
                expected results.
        """

        fingerprint = subprocess.check_output(
            [
                "adb",
                "-s",
                self.device_serial_or_address,
                "shell",
                "getprop",
                "ro.build.fingerprint",
            ],
            universal_newlines=True,
            timeout=self.device_access_timeout_secs,
        ).rstrip()

        self.logger.debug("Device reports fingerprint '%s'", fingerprint)

        return fingerprint

    def fix_result_file_fingerprints(self, result_dir):
        """Fix STS-manipulated device fingerprints in result files.

        This will replace the fingerprint in the result files with the correct
        fingerprint as reported by the device.

        Args:
            result_dir (str):
                Path to the result directory of the STS run to fix. This folder
                must contain a test_result.xml and test_result_failures.html,
                which are both present in a result folder of a completed
                TradeFed run.

        Raises:
            subprocess.CalledProcessError:
                If the device fingerprint could not be determined via adb.
        """

        if self.device_fingerprint is None:
            self.device_fingerprint = self.read_device_fingerprint()

        test_result_path = os.path.join(result_dir, "test_result.xml")
        test_result_path_orig = test_result_path + ".orig"
        shutil.move(test_result_path, test_result_path_orig)

        test_result_failures_path = os.path.join(
            result_dir, "test_result_failures.html"
        )
        test_result_failures_path_orig = test_result_failures_path + ".orig"
        shutil.move(test_result_failures_path, test_result_failures_path_orig)

        # Find the manipulated fingerprint in the result XML.
        test_result_tree = ET.parse(test_result_path_orig)
        result_build_node = test_result_tree.getroot().find("Build")
        manipulated_fingerprint = result_build_node.get("build_fingerprint")

        self.logger.debug(
            "Reverting STS manipulated device fingerprint: '%s' -> '%s'",
            manipulated_fingerprint,
            self.device_fingerprint,
        )

        # Fix the fingerprint in the result file.
        result_build_node.set("build_fingerprint", self.device_fingerprint)
        test_result_tree.write(test_result_path)

        # Fix the fingerprint in the failures overview HTML.
        with open(test_result_failures_path_orig, "r") as test_result_failures_file:
            test_result_failures = test_result_failures_file.read().replace(
                manipulated_fingerprint, self.device_fingerprint
            )
        with open(test_result_failures_path, "w") as test_result_failures_file:
            test_result_failures_file.write(test_result_failures)
