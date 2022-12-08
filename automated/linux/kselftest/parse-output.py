#!/usr/bin/env python3
import sys
import re


def slugify(line):
    non_ascii_pattern = r"[^A-Za-z0-9_-]+"
    line = re.sub(r"\[\d{1,5}\]", "", line)
    return re.sub(
        r"_-", "_", re.sub(r"(^_|_$)", "", re.sub(non_ascii_pattern, "_", line))
    )


tests = ""
for line in sys.stdin:
    if "# selftests: " in line:
        tests = slugify(line.replace("\n", "").split("selftests:")[1])
    elif re.search(r"^.*?not ok \d{1,5} ", line):
        match = re.match(r"^.*?not ok (.*?)$", line)
        ascii_test_line = slugify(re.sub("# .*$", "", match.group(1)))
        if f"selftests_{tests}" in output:
            output = re.sub(r"^.*_selftests_", "", output)
        print(f"{output}")
    elif re.search(r"^.*?ok \d{1,5} ", line):
        match = re.match(r"^.*?ok (.*?)$", line)
        if "# SKIP" in match.group(1):
            ascii_test_line = slugify(re.sub("# SKIP", "", match.group(1)))
            output = f"{tests}_{ascii_test_line} skip"
        else:
            ascii_test_line = slugify(match.group(1))
            output = f"{tests}_{ascii_test_line} pass"
        if f"selftests_{tests}" in output:
            output = re.sub(r"^.*_selftests_", "", output)
        print(f"{output}")
