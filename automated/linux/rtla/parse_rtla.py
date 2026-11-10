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
    parser.add_argument(
        "-c",
        "--return-code",
        dest="return_code",
        type=int,
        default=0,
        help="Exit code of rtla.",
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


def get_field_name(col):
    if col[0].endswith(":"):
        return col[0][:-1]
    return None


def to_number(value):
    # Newer rtla versions print the osnoise "avg:" with decimals.
    try:
        return int(value)
    except ValueError:
        return float(value)


def parse_histogram(col, sel, i, hist):
    if i not in hist:
        hist[i] = {}
        hist[i]["histogram"] = {}

    name = get_field_name(col)
    if name:
        hist[i][name] = to_number(col[sel])
    else:
        hist[i]["histogram"][col[0]] = to_number(col[sel])


def parse_osnoise(result_file, return_code):
    data = {}
    threads = {}
    cpus = []

    for line in result_file.readlines():
        if line.startswith(" ") or line.startswith("#"):
            continue

        col = line.split()
        if not col:
            continue
        if col[0] == "Index":
            # "Index   CPU-001   CPU-002 ...": key the results by CPU, as
            # with -c not every CPU has a column.
            cpus = [str(int(c.split("-")[1])) for c in col[1:]]
            continue
        name = get_field_name(col)
        if name == "ALL":
            break

        keys = cpus if len(cpus) == len(col) - 1 else range(len(col) - 1)
        for key, sel in zip(keys, range(1, len(col))):
            parse_histogram(col, sel, str(key), threads)

    data["file_version"] = 2
    data["return_code"] = return_code
    data["sysinfo"] = get_sysinfo()
    data["num_threads"] = len(threads)
    data["resolution_in_ns"] = 0
    data["thread"] = threads

    return data


def parse_timerlat(result_file, return_code):
    data = {}
    threads = {}
    irqs = {}
    num_cols = 0

    for line in result_file.readlines():
        if line.startswith(" "):
            continue

        col = line.split()
        name = get_field_name(col)
        if name == "ALL":
            break

        num_cols = len(col) - 1

        for i, sel in zip(range(0, num_cols), range(1, len(col), 2)):
            parse_histogram(col, sel, i, irqs)
        for i, sel in zip(range(0, num_cols), range(2, len(col), 2)):
            parse_histogram(col, sel, i, threads)

    data["file_version"] = 2
    data["return_code"] = return_code
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
            data = parse_osnoise(infile, args.return_code)
        else:
            data = parse_timerlat(infile, args.return_code)

    if args.output:
        with open(args.output, "w") as outfile:
            outfile.write(json.dumps(data, indent=2))
    else:
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main(parse_args())
