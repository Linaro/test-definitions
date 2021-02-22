import logging
import os.path
import re
import shutil
import subprocess
import sys
import time
from typing import Dict

sys.path.insert(0, "../../../lib/")
from py_util_lib import call_shell_lib  # nopep8


class Device:
    tcpip_device_re = re.compile(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{1,5}$")
    EXEC_IN_LAVA = shutil.which("lava-send") is not None

    def __init__(
        self,
        serial_or_address,
        logcat_output_filename,
        worker_job_id=None,
        userdata_image_file=None,
    ):
        self.serial_or_address = serial_or_address
        self.is_tcpip_device = bool(
            Device.tcpip_device_re.match(self.serial_or_address)
        )
        self.logcat_output_file = open(logcat_output_filename, "w")
        self.logcat = subprocess.Popen(
            ["adb", "-s", serial_or_address, "logcat"],
            stdout=self.logcat_output_file,
        )
        self.worker_job_id = worker_job_id
        self.worker_handshake_iteration = 1
        self.userdata_image_file = userdata_image_file
        self._is_available = True

    def ensure_available(self, logger, timeout_secs=30):
        """
        High level function that encapsulates all logic for ensuring that a device is accessible.
        Returns a boolean indicating if this function succeeded. This function will only return once
        the device is available or no other options for reestablishing a connection are known.

        Keyword arguments:
        tradefed_pexpect -- pexpect spawnu object that allows to communicate with TradeFed
        logger -- logging.getLogger() object to paste some debug information
        """
        if self.check_available(timeout_secs=timeout_secs):
            self._is_available = True
            logger.info("adb device %s is alive" % self.serial_or_address)
            # Tell the hosting worker that everything is fine
            self.worker_handshake("continue")
            return self._is_available

        self._is_available = False

        logger.debug(
            "adb connection to %s lost! Trying to reconnect..." % self.serial_or_address
        )

        # Tell the hosting worker that something is broken
        # This call will only return once the device is up and running again, if possible.
        self.worker_handshake("reconnect")

        if not self.try_reconnect():
            logger.warning(
                "adb connection to %s lost and reconnect failed!"
                % self.serial_or_address
            )
            return self._is_available

        logger.debug("Successfully reconnected to %s!" % self.serial_or_address)

        # TODO should check if TradeFed detected the device.

        self._is_available = True
        return self._is_available

    def is_available(self):
        """
        High level function that checks if the last ensure_available()
        invocation led to a positive result.
        """
        return self._is_available

    def check_available(self, timeout_secs=30):
        try:
            return (
                subprocess.run(
                    [
                        "adb",
                        "-s",
                        self.serial_or_address,
                        "shell",
                        "echo",
                        "%s:" % self.serial_or_address,
                        "OK",
                    ],
                    timeout=timeout_secs,
                ).returncode
                == 0
            )
        except subprocess.TimeoutExpired as e:
            print(e)
            return False

    def try_reconnect(self, reconnectTimeoutSecs=60):
        # NOTE: When running inside LAVA, self.is_tcpip_device == (self.worker_job_id is not None).
        # However, when running this script directly, there is no such thing as a remote worker ID,
        # and reconnect attempts to remote devices may still be useful.
        if not self.is_tcpip_device:
            # On local devices, we can currently only try to recover from fastboot.
            # This would be a good point for a hard reset.
            # NOTE: If the boot/reboot process takes longer than the specified timeout, this
            # function will return failure, but the device can still become accessible in the next
            # iteration of device availability checks.

            # `fastboot devices` prints in some versions more debug information
            # than `fastboot reboot`, e.g., missing udev rules.
            subprocess.run(["fastboot", "devices"])

            # There is no point in waiting longer for `fastboot reboot`:
            fastbootRebootTimeoutSecs = 10
            try:
                subprocess.run(
                    ["fastboot", "-s", self.serial_or_address, "reboot"],
                    timeout=fastbootRebootTimeoutSecs,
                )
            except subprocess.TimeoutExpired:
                # Blocking `fastboot reboot` does not necessarily indicate a
                # failure.
                pass

            subprocess.run(["fastboot", "devices"])

            bootTimeoutSecs = max(
                10, int(reconnectTimeoutSecs) - fastbootRebootTimeoutSecs
            )
            return self._call_shell_lib(
                "wait_boot_completed {}".format(bootTimeoutSecs)
            )

        # adb may not yet have realized that the connection is broken
        subprocess.run(["adb", "disconnect", self.serial_or_address])
        time.sleep(
            5
        )  # adb connect ~often~ fails when called ~directly~ after disconnect.

        try:
            if (
                subprocess.run(
                    ["adb", "connect", self.serial_or_address],
                    timeout=reconnectTimeoutSecs,
                ).returncode
                != 0
            ):
                return False
        except subprocess.TimeoutExpired:
            return False

        if not self.check_available():
            return False

        # Ensure that the device screen is on during test runs.
        if not self._call_shell_lib("disable_suspend"):
            print("WARNING: Disabling device suspend may have failed.")

        # reestablish logcat connection
        self.logcat.kill()
        self.logcat = subprocess.Popen(
            ["adb", "-s", self.serial_or_address, "logcat"],
            stdout=self.logcat_output_file,
        )
        return True

    def userdata_reset(self, commandTimeoutSecs=60, reconnectTimeoutSecs=900):
        """Reset the device to a clean state. This is equivalent to resetting to
        factory settings and applying CTS set-up steps."""
        if not self.userdata_image_file:
            print("WARNING: Skipping userdata_reset; no image file provided.")
            return True
        if not os.path.isfile(self.userdata_image_file):
            print(
                "WARNING: Skipping userdata_reset; image file not found: %s"
                % self.userdata_image_file
            )

        print("Resetting userdata partition on %s" % self.serial_or_address)

        # Reflash the userdata partition.
        if self.is_tcpip_device:
            self.worker_handshake("userdata_reset")
        else:
            try:
                subprocess.run(
                    [
                        "adb",
                        "-s",
                        self.serial_or_address,
                        "reboot",
                        "bootloader",
                    ],
                    timeout=commandTimeoutSecs,
                )
            except subprocess.TimeoutExpired:
                # Blocking `adb reboot` does not necessarily indicate a failure.
                pass
            try:
                subprocess.run(
                    [
                        "fastboot",
                        "-s",
                        self.serial_or_address,
                        "flash",
                        "userdata",
                        self.userdata_image_file,
                    ],
                    timeout=commandTimeoutSecs,
                )
            except subprocess.TimeoutExpired as e:
                print(e)
                return False

        # Reconnect as usual.
        if not self.try_reconnect(reconnectTimeoutSecs=reconnectTimeoutSecs):
            return False

    def release(self):
        self.logcat.kill()
        self.logcat_output_file.close()
        self.worker_handshake("release")

    def worker_handshake(self, command):
        """
        This function implements the counterpart of wait-and-keep-local-device-accessible.yaml
        It is basically a no-op when running outside LAVA.

        """

        # Nothing to do for local devices and nothing to do when not called by LAVA.
        if self.worker_job_id is None or not Device.EXEC_IN_LAVA:
            self.worker_handshake_iteration += 1
            return True

        # All commands except release are followed by a lava-send from the worker side.
        wait_for_acc = command != "release"

        subprocess.run(
            [
                "lava-send",
                "master-sync-%s-%s"
                % (self.worker_job_id, str(self.worker_handshake_iteration)),
                "command=%s" % command,
            ]
        )
        if wait_for_acc:
            subprocess.run(
                [
                    "lava-wait",
                    "worker-sync-%s-%s"
                    % (
                        self.worker_job_id,
                        str(self.worker_handshake_iteration),
                    ),
                ]
            )
            # TODO could check result variable from MultiNode cache
        self.worker_handshake_iteration += 1
        return True

    def _call_shell_lib(self, command: str) -> bool:
        """Call a function implemented in the (Android) shell library.
        Ensure that device-specific commands are executed on `self`.

        Arguments:
            command: Function defined in sh-test-lib or android-test-lib to
                call, including its parameters.
        Return:
            True if the executed shell exists with 0, False otherwise.
        """
        return call_shell_lib(command, device=self.serial_or_address) == 0


class RetryCheck:
    def __init__(self, total_max_retries, retries_if_unchanged):
        self.total_max_retries = total_max_retries
        self.retries_if_unchanged = retries_if_unchanged
        self.current_retry = 0
        self.current_unchanged = 0
        self.last_value = None

    def post_result(self, value):
        self.current_retry += 1
        if value == self.last_value:
            self.current_unchanged += 1
        else:
            self.current_unchanged = 1
            self.last_value = value

    def should_continue(self):
        return (
            self.current_retry < self.total_max_retries
            and self.current_unchanged < self.retries_if_unchanged
        )


class ResultSummary:
    def __init__(self, failure_count, modules_completed, modules_total, timestamp):
        self.failure_count = int(failure_count)
        self.modules_completed = int(modules_completed)
        self.modules_total = int(modules_total)
        self.timestamp = timestamp

    def was_successful(self):
        return self.failure_count == 0 and self.all_modules_completed()

    def all_modules_completed(self):
        return self.modules_completed == self.modules_total

    def __eq__(self, other):
        if isinstance(self, other.__class__):
            return self.__dict__ == other.__dict__
        return NotImplemented
