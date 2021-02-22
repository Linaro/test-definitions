#!/usr/bin/env python
import argparse
import json
import os
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument(
    "-s",
    "--source",
    dest="source",
    required=True,
    help="path to fuego test result file run.json.",
)
parser.add_argument(
    "-d",
    "--dest",
    dest="dest",
    required=True,
    help="Path to plain test result file result.txt.",
)
args = parser.parse_args()

with open(args.source) as f:
    data = json.load(f)

if "test_sets" not in data.keys():
    print("test_sets NOT found in {}".format(run_json))
    sys.exit(1)

result_lines = []
for test_set in data["test_sets"]:
    result_lines.append("lava-test-set start {}".format(test_set["name"]))

    for test_case in test_set["test_cases"]:
        # Functional
        result_line = "{} {}".format(test_case["name"], test_case["status"].lower())
        result_lines.append(result_line)

        # Benchmark
        if test_case.get("measurements"):
            for measurement in test_case["measurements"]:
                # Use test_case_name plus measurement name as test_case_id so
                # that it is readable and unique.
                result_line = "{}_{} {} {} {}".format(
                    test_case["name"],
                    measurement["name"],
                    measurement["status"].lower(),
                    measurement["measure"],
                    measurement.get("unit", ""),
                )
                result_lines.append(result_line)

    result_lines.append("lava-test-set stop {}".format(test_set["name"]))

with open(args.dest, "w") as f:
    for result_line in result_lines:
        print(result_line)
        f.write("{}\n".format(result_line))
