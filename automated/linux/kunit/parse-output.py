#!/usr/bin/env python3
import sys
import re
from tap import parser


def slugify(line):
    non_ascii_pattern = r"[^A-Za-z0-9_-]+"
    line = re.sub(r"\[\d{1,5}\]", "", line)
    return re.sub(
        r"_-", "__", re.sub(r"(^_|_$)", "", re.sub(non_ascii_pattern, "_", line))
    )


def parse_nested_tap(string):
    results = []
    subtest = None
    current_result = None
    pending_logs = []

    ps = parser.Parser()
    lines = string.splitlines()

    for raw_line in lines:
        parsed_line = ps.parse_line(raw_line)

        if parsed_line is None:
            pending_logs.append(raw_line.strip())
            continue

        if parsed_line.category == "diagnostic":
            if parsed_line.text.startswith("# Subtest:"):
                subtest = parsed_line.text.split(":", 1)[1].strip()
            else:
                pending_logs.append(parsed_line.text.lstrip("#").strip())

        elif parsed_line.category == "test":
            name = parsed_line.description.strip()

            if (
                not name
                or "ASSERTION FAILED" in name
                or name.lower() == "totals"
                or (subtest and name == subtest)
            ):
                current_result = None
                pending_logs = []
                continue

            full_name = slugify(f"{subtest}_{name}" if subtest else name)
            result = {
                "name": full_name,
                "result": (
                    ("skip" if parsed_line.skip else "pass")
                    if parsed_line.ok
                    else "fail"
                ),
                "logs": "",
            }

            if pending_logs:
                result["logs"] = "\n".join(pending_logs) + "\n"
                pending_logs = []

            results.append(result)
            current_result = result

        else:
            pending_logs.append(raw_line.strip())

    return results


if __name__ == "__main__":
    raw_input = sys.stdin.read()
    cleaned_input = re.sub(r"<\d+>\[\s*\d+\.\d+\]\s*", "", raw_input)
    results = parse_nested_tap(cleaned_input)
    for r in results:
        print(f"{r['name']} {r['result']}")
