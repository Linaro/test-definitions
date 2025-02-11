"""Shared Python 3 utility code."""

from pathlib import Path
import subprocess
from typing import Dict, Optional

AUTOMATED_LIB_DIR = Path(__file__).resolve().parent


def call_shell_lib(
    command: str,
    environment: Optional[Dict[str, str]] = None,
    device: Optional[str] = None,
) -> int:
    """Python-to-shell adaptor, facilitating code reuse.

    This executes a given command line on a shell with sourced sh-test-lib and
    android-test-lib.

    Arguments:
        command: Function or command line including parameters to execute in a
            shell.
        environment: Environment to execute the shell command in. This is a
            mapping of environment variable names to their values.
        device: ADB identifier (serial or IP and port) of a device. If set, this
            will be appended as ANDROID_SERIAL to the environment.
    Return:
        The exit code of the invoked shell command.
    """
    if device:
        if not environment:
            environment = {}
        environment["ANDROID_SERIAL"] = device
    return subprocess.run(
        [
            "sh",
            "-c",
            ". {}/sh-test-lib && "
            ". {}/android-test-lib && {}".format(
                AUTOMATED_LIB_DIR, AUTOMATED_LIB_DIR, command
            ),
        ],
        env=environment,
    ).returncode
