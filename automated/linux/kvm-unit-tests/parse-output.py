#!/usr/bin/env python3
import sys
import re


def parse_line(line):
    """
    Parses a single line of input to extract the test result and description.

    Args:
        line (str): A single line of input.

    Returns:
        tuple: A tuple containing the result and description.
    """

    if not line.startswith("ok") and not line.startswith("not ok"):
        return None, None

    parts = re.split(r" \d+ - ", line)
    if len(parts) < 2:
        raise ValueError(f"Invalid line format: {line}")

    result = "pass" if parts[0] == "ok" else "fail"
    description = parts[1].strip()

    if "# skip" in description.lower():
        result = "skip"
        description = description.split("# skip")[0].strip()

    return result, description


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
        result, description = parse_line(line)

        if not result or not description:
            continue

        print(f"{sanitize_description(description)} {result}")


if __name__ == "__main__":
    main()
