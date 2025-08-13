#!/usr/bin/env python3
import sys
import re


def parse_line(line):
    """
    Parses a single line of input to extract the test result and description.

    Args:
        line (str): A single line of input.

    Returns:
        triple: A triple containing the result, description, and
        error_log.
    """
    error_log = None
    if not line.startswith("ok") and not line.startswith("not ok"):
        return None, None, None

    parts = re.split(r" \d+ - ", line)
    if len(parts) < 2:
        raise ValueError(f"Invalid line format: {line}")

    result = "pass" if parts[0] == "ok" else "fail"
    description = parts[1].strip()

    if ": " in description and result == "fail":
        desc_part, error_part = description.split(": ", 1)
        description = desc_part.strip()
        error_log = error_part.strip()

    if "# skip" in description.lower():
        result = "skip"
        description = description.split("# skip")[0].strip()

    return result, description, error_log


def sanitize_description(description):
    """
    Sanitizes the description by replacing spaces with dashes, removing special characters, and avoiding double dashes.

    Args:
        description (str): The test description.

    Returns:
        str: The sanitized description.
    """
    description = description.replace(" ", "-")
    description = re.sub(r"[^a-zA-Z0-9_-]+", "", description)  # Slugify
    description = re.sub(
        r"-+", "-", description
    )  # Replace multiple dashes with a single dash
    return description


def main():
    """
    Main function to parse input, process each line, and output the results.
    """
    lines = sys.stdin.readlines()

    for line in lines:
        result, description, error_log = parse_line(line)

        if not result or not description:
            continue
        print(f"{sanitize_description(description)} {result}")


if __name__ == "__main__":
    main()
