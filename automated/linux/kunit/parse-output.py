#!/usr/bin/env python3
import sys
import re


def slugify(line):
    non_ascii_pattern = r"[^A-Za-z0-9_-]+"
    return re.sub(non_ascii_pattern, "", line)


tests = ""
for line in sys.stdin:
    totals = False
    if "# Subtest: " in line:
        tests = line.replace("\n", "").split(":")[1]
    elif "# Totals: pass:" in line:
        totals = True
    elif not totals and re.search(r"^.* not ok \d{1,5} ", line):
        match = re.match(r"^.* not ok \d{1,5} (.*?)$", line)
        ascii_test_line = slugify(match.group(1))
        print(f"{tests}_{ascii_test_line} fail")
    elif not totals and re.search(r"^.* ok \d{1,5} ", line):
        match = re.match(r"^.* ok \d{1,5} (.*?)$", line)
        if "# SKIP" in match.group(1):
            ascii_test_line = slugify(match.group(1).split("# SKIP")[0])
            print(f"{tests}_{ascii_test_line} skip")
        else:
            ascii_test_line = slugify(match.group(1))
            print(f"{tests}_{ascii_test_line} pass")
