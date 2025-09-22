#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.

import argparse

from robot.api import ExecutionResult, ResultVisitor


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


def main():
    result = ExecutionResult(args.result_file)

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
