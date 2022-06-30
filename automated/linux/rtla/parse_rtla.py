#!/usr/bin/env python3
import argparse
import platform
import json

# Transform rtla hist out data into the same format as rt-tests
# framework is producing.


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-r",
        "--result-file",
        dest="result_file",
        required=True,
        default="./result.txt",
        help="Specify test result file.",
    )
    parser.add_argument(
        "-t",
        "--test-name",
        required=True,
        help="Specify test name.",
    )
    parser.add_argument(
        "-o",
        "--output",
        dest="output",
        help="Specify output file.",
    )

    args = parser.parse_args()
    return args


def get_sysinfo():
    sysinfo = {}

    uname = platform.uname()
    sysinfo["sysname"] = uname.system
    sysinfo["nodename"] = uname.node
    sysinfo["release"] = uname.release
    sysinfo["version"] = uname.version
    sysinfo["machine"] = uname.machine

    realtime = 0
    try:
        with open("/sys/kernel/realtime", "r") as rfl:
            realtime = int(rfl.read(1))
    except IOError:
        pass
    sysinfo["realtime"] = realtime

    return sysinfo


def parse_histogram(col, sel, i, hist):
    if i not in hist:
        hist[i] = {}
        hist[i]["histogram"] = {}

    if col[0].endswith(":"):
        name = col[0][:-1]
        hist[i][name] = int(col[sel])
    else:
        hist[i]["histogram"][col[0]] = int(col[sel])


def parse_osnoise(result_file):
    data = {}
    threads = {}
    for line in result_file.readlines():
        if line.startswith(" "):
            continue

        col = line.split()

        num_cols = len(col) - 1

        for i, sel in zip(range(0, num_cols), range(1, len(col), 1)):
            parse_histogram(col, sel, i, threads)

    data["file_version"] = 2
    data["return_code"] = 0
    data["sysinfo"] = get_sysinfo()
    data["num_threads"] = num_cols
    data["resolution_in_ns"] = 0
    data["thread"] = threads

    return data


def parse_timerlat(result_file):
    data = {}
    threads = {}
    irqs = {}
    num_cols = 0
    for line in result_file.readlines():
        if line.startswith(" "):
            continue

        col = line.split()

        num_cols = len(col) - 1

        for i, sel in zip(range(0, num_cols), range(1, len(col), 2)):
            parse_histogram(col, sel, i, irqs)
        for i, sel in zip(range(0, num_cols), range(2, len(col), 2)):
            parse_histogram(col, sel, i, threads)

    data["file_version"] = 2
    data["return_code"] = 0
    data["sysinfo"] = get_sysinfo()
    data["num_threads"] = num_cols / 2
    data["num_irqs"] = num_cols / 2
    data["resolution_in_ns"] = 0
    data["thread"] = threads
    data["irq"] = irqs

    return data


def main(args):
    with open(args.result_file, "r") as infile:
        if args.test_name == "osnoise":
            data = parse_osnoise(infile)
        else:
            data = parse_timerlat(infile)

    if args.output:
        with open(args.output, "w") as outfile:
            outfile.write(json.dumps(data, indent=2))
    else:
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main(parse_args())
