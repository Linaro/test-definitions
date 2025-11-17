#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.

import sys

from junitparser import JUnitXml


def parse_junit(file: str) -> list[str]:
    results: list[str] = []

    try:
        xml = JUnitXml.fromfile(file)
    except Exception as e:
        print(f"Junit parse exception: {e}")
        raise SystemExit(1)

    for suite in xml:
        for case in suite:
            if case.is_passed:
                result = "pass"
            elif case.is_failure or case.is_error:
                result = "fail"
            elif case.is_skipped:
                result = "skip"
            else:
                result = "unknown"

            test_case_id = case.classname.replace(".", "_") + "_" + case.name
            result_line = f"{test_case_id} {result}"
            results.append(result_line)
            print(result_line)

    return results


def main() -> None:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <pytest-junit.xml>")
        raise SystemExit(1)

    results = parse_junit(sys.argv[1])

    with open("result.txt", "w") as f:
        for result in results:
            f.write(f"{result}\n")


if __name__ == "__main__":
    main()
