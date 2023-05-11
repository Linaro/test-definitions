#!/usr/bin/env python3
import sys
import re


def slugify(line):
    non_ascii_pattern = r"[^A-Za-z0-9_-]+"
    line = re.sub(r"\[\d{1,5}\]", "", line)
    line = re.sub(r"^_", "", line)
    return re.sub(
        r"_-", "_", re.sub(r"(^_|_$)", "", re.sub(non_ascii_pattern, "_", line))
    )


tests = ""
for line in sys.stdin:
    if re.search(r"^.*?not ok \d{1,5} ", line):
        match = re.match(r"^.*?not ok [0-9]+ (.*?)$", line)
        ascii_test_line = slugify(re.sub("# .*$", "", match.group(1)))
        output = f"{tests}_{ascii_test_line} fail"
        print(f"{output}")
    elif re.search(r"^ok \d{1,5} ", line):
        match = re.match(r"^.*?ok [0-9]+ (.*?)$", line)
        ascii_test_line = slugify(match.group(1))
        output = f"{tests}_{ascii_test_line} pass"
        print(f"{output}")
