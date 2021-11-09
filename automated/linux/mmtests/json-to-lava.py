#!/usr/bin/python3

# Converts mmtests test results from JSON format to a list of strings
# with the following structure so LAVA can understand it:
# <module_name>_<op>_<iteration>_<sample> pass <value>
# <module_name>_<$field>_<none>_<value> pass <0>

import argparse
import json
from base64 import b64encode


def main(args):
    exitcode = 0
    with open(args.json_file) as f:
        module = json.load(f)
        module_name = module["_ModuleName"].replace("Extract", "").lower()
        data = module["_ResultData"]
        operations = list(data)
        iterations = len(data[operations[0]])
        for i in range(iterations):
            for op in operations:
                op_data = data[op][i]
                values = op_data["Values"]
                samples = op_data["SampleNrs"]
                op.replace("_", "-")
                for val, sample in zip(values, samples):
                    print(f"{module_name}_{op}_{i}_{sample} pass {val}")
        if "_Cmd" in module:
            string = ""
            for i in range(len(module["_Cmd"])):
                string = string + module["_Cmd"][i]
            b64string = b64encode(bytes(string, "utf-8")).decode("utf-8")
            print(f"{module_name}_$Cmd_0_{b64string} pass {0}")
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
