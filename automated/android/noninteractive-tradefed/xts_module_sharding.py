#!/usr/bin/env python3

import argparse
import logging
import os
import sys
from lxml import etree


def get_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="XTS module static sharding parser")
    parser.add_argument(
        "-p",
        "--test-path",
        required=True,
        # TODO: check the possibility to split cts plan/config.
        choices=["android-vts"],
        help="Path to tradefed package top directory.",
    )
    parser.add_argument(
        "-t", "--test-params", required=True, help="Tradefed shell test parameters."
    )
    parser.add_argument(
        "-n",
        "--shard-number",
        required=True,
        help="The number of shards of a test module.",
    )
    parser.add_argument(
        "-i",
        "--shard-index",
        required=True,
        help="The index of the test module shard to run.",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", default=False, help="Be verbose."
    )

    return parser


def shards(lst: list, n: int) -> list:
    "Yield successive n-sized list shards from a given list."
    for i in range(0, len(lst), n):
        yield lst[i : i + n]


def update_config(config: str, shard_number: int, shard_index: int) -> None:
    """
    Update module config to keep the tests_number//shard_number sized
    shard #shard_index only.
    """
    tree = etree.parse(config)
    root = tree.getroot()

    # vts test modules like ltp and kselftest modules contain
    # name="test-command-line" attribute for each sub-test. It can be
    # used to identify tests. Other options like below ones should be
    # kept for every shard.
    # <option name="skip-binary-check" value="true"/>
    # <option name="per-binary-timeout" value="1080000"/>
    options = root.xpath('/configuration/test/option[@name="test-command-line"]')
    sub_test_number = len(options)
    if sub_test_number == 0:
        logging.warning(
            'Test options with name="test-command-line" attribute not found!'
        )
        logging.warning("Test sharding skipped.")
        sys.exit(0)
    logging.info(f"Original test size: {sub_test_number}")
    if sub_test_number < shard_number:
        logging.warning(f"Test number {sub_test_number} is smaller than shard number.")
        logging.warning("Test sharding skipped.")
        sys.exit(0)
    n = sub_test_number // shard_number
    logging.info(f"Test shard size: {n}")

    count = 1
    logging.info(f"Updating module config to keep {n}-sized shard #{shard_index} only")
    for options_shard in shards(options, n):
        if count != shard_index:
            for option in options_shard:
                option.getparent().remove(option)
        count += 1
    updated_size = len(
        root.xpath('/configuration/test/option[@name="test-command-line"]')
    )
    logging.info(f"Updated test size: {updated_size}")

    tree.write(config, pretty_print=True, xml_declaration=True, encoding="utf-8")
    logging.info(f"Updated {config}")


def main():
    args = get_parser().parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s: %(levelname)s: %(funcName)s: %(message)s",
    )
    logging.debug(f"Arguments: {args}")

    # Find the module config file.
    # Both --module and --include-filter args can be used to specify
    # test module. Usage examples:
    # vts: run vts-kernel [--module module]
    # cts: run cts [--include-filter module]
    supported_args = [
        "--module",
        "--include-filter",
    ]
    params = args.test_params.split()
    count = 0
    for supported_arg in supported_args:
        count += params.count(supported_arg)
    if count > 1:
        logging.warning(
            f"module sharding supports only one module but {count} modules found."
        )
        logging.info("Module sharding skipped.")
        # exit with 0 to let tests to run.
        sys.exit(0)
    for param in params:
        if param in supported_args:
            param_index = params.index(param)
            module_name = params[param_index + 1]
    module_config = os.path.join(
        args.test_path, "testcases", module_name, module_name + ".config"
    )
    module_config = os.path.realpath(module_config)
    if os.path.exists(module_config):
        logging.info(f"{module_config} found.")
    else:
        logging.warning(f"{module_config} not found!")
        logging.warning("Module sharding skipped.")
        sys.exit(0)

    # Shard number and index sanity checks.
    shard_number = int(args.shard_number)
    shard_index = int(args.shard_index)
    if shard_index > shard_number:
        logging.error("Shard index should be less than or equal to shard number.")
        sys.exit(1)
    if shard_number == 1:
        sys.exit(0)
    if shard_number > 1:
        logging.info(f"Splitting {module_name} into {shard_number} shards ...")

    update_config(module_config, shard_number, shard_index)


if __name__ == "__main__":
    main()
