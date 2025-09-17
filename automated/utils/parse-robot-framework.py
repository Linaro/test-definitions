#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.

import io
import os
import argparse

from datetime import datetime

from paramiko import SSHClient, AutoAddPolicy, RSAKey
from robot.api import ExecutionResult, ResultVisitor
from scp import SCPClient


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-r",
        "--result-file",
        dest="result_file",
        default="./output.xml",
        help="Specify robot framework XML test result file.",
    )
    args = parser.parse_args()
    return args


def send_output(result_file):
    print("connecting to ssh server...")
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    server = os.getenv("SSH_SERVER")
    username = os.getenv("SSH_USERNAME")
    try:
        pkey = RSAKey.from_private_key(io.StringIO(os.getenv("SSH_KEY")))
    except Exception as ex:
        print(f"Not able to get SSH_KEY: {os.getenv("SSH_KEY")}, exception msg: {ex}")

    with SSHClient() as ssh:
        try:
            ssh.set_missing_host_key_policy(AutoAddPolicy())
            ssh.connect(hostname=server, username=username, pkey=pkey)
        except Exception as ex:
            print(
                f"Failed to make SSH connection to server due to the following exception: {ex}"
            )

        with SCPClient(ssh.get_transport()) as scp:
            try:
                scp.put(
                    result_file,
                    f"~/public_html/remote_robot_dash/output-{timestamp}.xml",
                )
                print(f"file {result_file} sent to fileserver")
            except Exception as ex:
                print(
                    f"Failed to send {result_file} to server due to the following exception: {ex}"
                )


def main():
    result = ExecutionResult(args.result_file)

    send_output(args.result_file)

    def get_all_tests(suite):
        for test in suite.tests:
            yield test
        for sub_suite in suite.suites:
            yield from get_all_tests(sub_suite)

    for test in get_all_tests(result.suite):
        print(
            f"<LAVA_SIGNAL_TESTCASE TEST_CASE_ID={test.name.replace(' ', '')} RESULT={test.status.lower()}>"
        )


if __name__ == "__main__":
    args = parse_args()
    main()
