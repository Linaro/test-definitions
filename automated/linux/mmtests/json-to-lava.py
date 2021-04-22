#!/usr/bin/python3

# Converts mmtests test results from JSON format to a list of strings
# with the following structure so LAVA can understand it:
# <module_name>-<test_name>-<op>-<iteration>-<sample> pass <value>

import argparse
import json


def main(args):
    exitcode = 0
    with open(args.json_file) as f:
        module = json.load(f)
        module_name = module["_ModuleName"].replace("Extract", "").lower()
        test_name = module["_TestName"]
        data = module["_ResultData"]
        operations = list(data)
        iterations = len(data[operations[0]])
        for i in range(iterations):
            for op in operations:
                op_data = data[op][i]
                values = op_data["Values"]
                samples = op_data["SampleNrs"]
                for val, sample in zip(values, samples):
                    print(f"{module_name}-{test_name}-{op}-{i}-{sample} pass {val}")
    exit(exitcode)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Formats mmtests loadable json to lava results format"
    )
    parser.add_argument(
        "json_file",
        type=str,
        nargs="?",
        help="JSON file to convert in a test result acceptable for lava",
    )
    args = parser.parse_args()
    main(args)
