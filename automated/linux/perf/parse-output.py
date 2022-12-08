#!/usr/bin/env python3
import sys
import re


def slugify(line):
    non_ascii_pattern = r"[^A-Za-z0-9_-]+"
    line = re.sub(r"/tmp/perf.*$", "", line)
    return re.sub(r"_-", "_", re.sub(r"_$", "", re.sub(non_ascii_pattern, "_", line)))


tests = ""
for line in sys.stdin:
    totals = False
    if line.endswith(" Ok\n"):
        tests = line.replace(" Ok", "")
        ascii_test_line = slugify(tests)
        print(f"{ascii_test_line} pass")
    elif line.endswith(" FAILED!\n"):
        tests = line.replace(" FAILED!", "")
        ascii_test_line = slugify(tests)
        print(f"{ascii_test_line} fail")
    elif line.endswith(" Skip") or " Skip (" in line:
        tests = re.sub(" Skip.*$", "", line)
        ascii_test_line = slugify(tests)
        print(f"{ascii_test_line} skip")
