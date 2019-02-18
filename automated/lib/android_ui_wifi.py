#!/usr/bin/env python3

from android_adb_wrapper import *
import argparse
import sys
from uiautomator import Device


def set_wifi_state(dut, turn_on):
    """Turn WiFi on or off.

        This checks the current WiFi settings and turns it on or off. It does
        nothing if the settings are already in the desired state.

        Parameters:
            dut (Device): The device object.
            enabled: Boolean, true for on, false for off
        Raises:
            DeviceCommandError: If the UI automation fails.
    """
    # Open the Wi-Fi settings
    adb(
        "shell",
        ("am start -a android.settings.WIFI_SETTINGS " "--activity-clear-task"),
        serial=dut.serial,
    )

    # Check if there is an option to turn WiFi on or off
    wifi_enabler = dut(
        text="OFF", resourceId="com.android.settings:id/switch_widget"
    )
    wifi_disabler = dut(
        text="ON", resourceId="com.android.settings:id/switch_widget"
    )

    if not wifi_enabler.exists and not wifi_disabler.exists:
        raise DeviceCommandError(
            dut,
            "UI: set Wi-Fi state",
            "Neither switch for turning Wi-Fi on nor for turning it off are present.",
        )
    if wifi_enabler.exists and wifi_disabler.exists:
        raise DeviceCommandError(
            dut,
            "UI: set Wi-Fi state",
            "Unexpected UI: Both, a switch for turning Wi-Fi on and for turning it off are present.",
        )

    if turn_on:
        if wifi_enabler.exists:
            wifi_enabler.click()
        else:
            print("Wi-Fi is already enabled.")
    else:
        if wifi_disabler.exists:
            wifi_disabler.click()
        else:
            print("Wi-Fi is already disabled.")

    # Leave the settings
    dut.press.back()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-a",
        dest="ACTION",
        required=True,
        nargs="+",
        help="Action to perform. Following action is currently implemented: \
                        set_wifi_state <on|off>",
    )
    parser.add_argument(
        "-s",
        dest="SERIALS",
        nargs="+",
        help="Serial numbers of devices to configure. \
                        If not present, all available devices will be configured.",
    )
    args = parser.parse_args()

    if args.ACTION[0] != "set_wifi_state" or args.ACTION[1] not in (
        "on",
        "off",
    ):
        print(
            "ERROR: Specified ACTION is not supported: {}".format(args.ACTION),
            file=sys.stderr,
        )
        sys.exit(1)

    serials = args.SERIALS if args.SERIALS is not None else list_devices()

    for serial in serials:
        print("Configuring device {}…".format(serial))

        dut = Device(serial)
        # Work around the not-so-easy Device class
        dut.serial = serial

        try:
            unlock(dut)

            set_wifi_state(dut, args.ACTION[1] == "on")

        except DeviceCommandError as e:
            print("ERROR {}".format(e), file=sys.stderr)


if __name__ == "__main__":
    main()
