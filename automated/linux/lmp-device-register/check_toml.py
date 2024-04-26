#!/usr/bin/env python3

import argparse
import sys


def main(toml_file):
    info = sys.version_info
    if info.major >= 3 and info.minor >= 11:
        import tomllib as tlib
    else:
        import toml as tlib

    with open(toml_file, "rb") as f:
        tlib.loads(f.read().decode())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--toml-file", required=True)
    args = parser.parse_args()
    main(args.toml_file)
