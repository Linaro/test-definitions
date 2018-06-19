#!/usr/bin/env python3

import re
import subprocess
import time


ADB_DEVICES_PATTERN = re.compile(r"^([a-z0-9-]+)\s+device$", flags=re.M)


class DeviceCommandError(BaseException):
    """An error happened while sending a command to a device."""

    def __init__(self, serial, command, error_message):
        self.serial = serial
        self.command = command
        self.error_message = error_message
        message = "Command `{}` failed on {}: {}".format(
            command, serial, error_message
        )
        super(DeviceCommandError, self).__init__(message)


def adb(*args, serial=None, raise_on_error=True):
    """Run ADB command attached to serial.

    Example:
    >>> process = adb('shell', 'getprop', 'ro.build.fingerprint', serial='aserialnumber')
    >>> process.returncode
    0
    >>> process.stdout.strip()
    'ExampleVendor/Device/version/tags'

    :param *args:
        List of options to ADB (including command).
    :param str serial:
        Identifier for ADB connection to device.
    :param raise_on_error bool:
        Whether to raise a DeviceCommandError exception if the return code is
        less than 0.
    :returns subprocess.CompletedProcess:
        Completed process.
    :raises DeviceCommandError:
        If the command failed.
    """

    # Make sure the adb server is started to avoid the infamous "out of date"
    # message that pollutes stdout.
    ret = subprocess.run(
        ["adb", "start-server"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if ret.returncode < 0:
        if raise_on_error:
            raise DeviceCommandError(
                serial if serial else "??", str(args), ret.stderr
            )
        else:
            return None

    command = ["adb"]
    if serial:
        command += ["-s", serial]
    if args:
        command += list(args)
    ret = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )

    if raise_on_error and ret.returncode < 0:
        raise DeviceCommandError(
            serial if serial else "??", str(args), ret.stderr
        )

    return ret


def list_devices():
    """List serial numbers of devices attached to adb.

    Raises:
        DeviceCommandError: If the underlying adb command failed.
    """
    process = adb("devices")
    return ADB_DEVICES_PATTERN.findall(process.stdout)


def unlock(dut):
    """Wake-up the device and unlock it.

    Raises:
        DeviceCommandError: If the underlying adb commands failed.
    """
    if not dut.info["screenOn"]:
        adb("shell", "input keyevent KEYCODE_POWER", serial=dut.serial)
        time.sleep(1)

    # Make sure we are on the home screen.
    adb("shell", "input keyevent KEYCODE_HOME", serial=dut.serial)
    # The KEYCODE_MENU input is enough to unlock a "swipe up to unlock"
    # lockscreen on Android 6, but unfortunately not Android 7. So we use a
    # swipe up (that depends on the screen resolution) instead.
    adb("shell", "input touchscreen swipe 930 880 930 380", serial=dut.serial)
    time.sleep(1)
    adb("shell", "input keyevent KEYCODE_HOME", serial=dut.serial)
