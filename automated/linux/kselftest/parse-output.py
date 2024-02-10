#!/usr/bin/env python3
import sys
import re
from tap import parser


def slugify(line):
    non_ascii_pattern = r"[^A-Za-z0-9_-]+"
    line = re.sub(r"\[\d{1,5}\]", "", line)
    return re.sub(
        r"_-", "_", re.sub(r"(^_|_$)", "", re.sub(non_ascii_pattern, "_", line))
    )


def parse_nested_tap(string):
    results = []

    def uncomment(line):
        # All of the input lines should be comments and begin with #, but let's
        # be cautious; don't do anything if the line doesn't begin with #.
        if len(line) > 0 and line[0] == "#":
            return line[1:].strip()
        return line

    def make_name(name, directive, ok, skip):
        # Some of this is to maintain compatibility with the old parser.
        if name.startswith("selftests:"):
            name = name[10:]
        if ok and skip and directive.lower().startswith("skip"):
            directive = directive[4:]
        else:
            directive = ""
        name = f"{name} {directive}".strip()
        if name == "":
            name = "<unknown>"
        return slugify(name)

    def make_result(ok, skip):
        return ("skip" if skip else "pass") if ok else "fail"

    output = ""
    ps = parser.Parser()
    for l in ps.parse_text(string):
        if l.category == "test":
            results.append(
                {
                    "name": make_name(l.description, l.directive.text, l.ok, l.skip),
                    "result": make_result(l.ok, l.skip),
                    "children": parse_nested_tap(output),
                }
            )
            output = ""
        elif l.category == "diagnostic":
            output += f"{uncomment(l.text)}\n"

    return results


def flatten_results(prefix, results):
    ret = []
    for r in results:
        test = f"{prefix}{r['name']}"
        children = flatten_results(f"{test}_", r["children"])
        ret += children + [{"name": test, "result": r["result"]}]
    return ret


def make_names_unique(results):
    namecounts = {}
    for r in results:
        name = r["name"]
        namecounts[name] = namecounts.get(name, 0) + 1
        if namecounts[name] > 1:
            r["name"] += f"_dup{namecounts[name]}"


if __name__ == "__main__":
    results = parse_nested_tap(sys.stdin.read())
    results = flatten_results("", results)
    make_names_unique(results)
    for r in results:
        print(f"{r['name']} {r['result']}")
