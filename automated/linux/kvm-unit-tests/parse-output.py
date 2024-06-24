#!/usr/bin/env python3

import sys
import re


def parse_input_file():
    """
    Reads lines from the standard input.

    Returns:
        list: A list of lines read from the input.
    """
    try:
        lines = sys.stdin.readlines()
        return lines
    except Exception as e:
        sys.stderr.write(f"Error reading input: {e}\n")
        sys.exit(1)


def parse_line(line):
    """
    Parses a single line of input to extract the test result and description.

    Args:
        line (str): A single line of input.

    Returns:
        tuple: A tuple containing the result and description.
    """
    parts = line.split(" ", 2)
    if len(parts) < 3:
        raise ValueError(f"Invalid line format: {line}")

    status = parts[0]
    description = parts[2].strip()

    if status == "ok":
        result = "pass"
    elif status == "not" and parts[1] == "ok":
        result = "fail"
        description = parts[2].split(" ", 1)[1].strip()
    else:
        result = "unknown"

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
    description = re.sub(
        r"[^a-zA-Z0-9\-]", "", description
    )  # Remove special characters
    description = re.sub(
        r"-+", "-", description
    )  # Replace multiple dashes with a single dash
    description = description.strip("-")  # Remove leading and trailing dashes
    return description


def format_output(result, description):
    """
    Formats the parsed data into the desired output format.

    Args:
        result (str): The test result (pass, fail, skip).
        description (str): The test description.

    Returns:
        str: The formatted output string.
    """
    sanitized_description = sanitize_description(description)
    return f"{sanitized_description} {result}\n"


def main():
    """
    Main function to parse input, process each line, and output the results.
    """
    try:
        lines = parse_input_file()
        for line in lines:
            try:
                result, description = parse_line(line)
                formatted_line = format_output(result, description)
                sys.stdout.write(formatted_line)
            except ValueError as e:
                sys.stderr.write(f"Error processing line: {e}\n")
                continue
    except Exception as e:
        sys.stderr.write(f"Unexpected error: {e}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
