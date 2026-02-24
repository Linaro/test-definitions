#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2026 Linaro Ltd.
"""Generate markdown documentation from YAML test definitions.

Walks the test directories, reads YAML files with metadata sections,
and generates markdown pages, an index table, and a tags page.
Run this before building the docs.
"""

import argparse
import logging
import os

import yaml

TABLE_DIRS = ["automated/linux", "automated/android", "manual"]
TABLE_FILENAME = "tests_table"
DOCS_DIR = "docs"

log = logging.getLogger(__name__)


def tag_anchor(tag):
    """Convert a tag name to a URL anchor."""
    return tag.lower().replace(" ", "-").replace("/", "")


def parse_test_definition(filepath):
    """Parse a YAML test definition file.

    Returns a dict with name, description, scope, os, devices, maintainer,
    and steps. Returns None if the file has no metadata section.
    """
    try:
        with open(filepath, "r") as f:
            content = yaml.safe_load(f)
    except FileNotFoundError:
        return None
    except yaml.YAMLError as e:
        log.warning("%s: invalid YAML: %s", filepath, e)
        return None

    if not isinstance(content, dict) or "metadata" not in content:
        return None

    metadata = content["metadata"]
    if "name" not in metadata:
        log.warning("%s: metadata missing 'name'", filepath)
        return None

    try:
        steps = content["run"]["steps"]
    except (KeyError, TypeError):
        log.warning("%s: missing run.steps", filepath)
        return None

    return {
        "name": metadata["name"],
        "description": metadata.get("description", ""),
        "scope": metadata.get("scope", []),
        "os": metadata.get("os", []),
        "devices": metadata.get("devices", []),
        "maintainer": metadata.get("maintainer", []),
        "steps": steps,
    }


def build_frontmatter(name, scope_list):
    """Build YAML frontmatter for a markdown page."""
    lines = ["---", "title: %s" % name]
    if scope_list:
        lines.append("tags:")
        for item in scope_list:
            lines.append(" - %s" % item)
    lines.append("---")
    return "\n".join(lines)


def build_md_list(header, items):
    """Build a markdown section with a header and bullet list."""
    lines = ["\n## %s\n" % header]
    for item in items:
        lines.append(" * %s" % item)
    return "\n".join(lines)


def build_test_page(rel_path, definition):
    """Build the full markdown content for a test page."""
    parts = [build_frontmatter(definition["name"], definition["scope"])]
    parts.append("\n# %s\n" % rel_path)

    parts.append("\n## Description\n")
    parts.append(definition["description"])

    if definition["maintainer"]:
        parts.append(build_md_list("Maintainer", definition["maintainer"]))
    else:
        parts.append("\n## Maintainer\n")

    parts.append(build_md_list("OS", definition["os"]))
    parts.append(build_md_list("Scope", definition["scope"]))
    parts.append(build_md_list("Devices", definition["devices"]))

    parts.append("\n## Steps to reproduce\n")
    for line in definition["steps"]:
        text = str(line)
        if text.startswith("#"):
            parts.append(" * \\%s" % text)
        else:
            parts.append(" * %s" % text)

    return "\n".join(parts) + "\n"


def write_test_page(filepath, docs_dir, definition):
    """Write a markdown page for a single test definition.

    Returns the relative path (without docs_dir prefix) on success.
    """
    # strip .yaml extension
    rel_path = filepath.rsplit(".", 1)[0]

    out_path = os.path.join(docs_dir, rel_path + ".md")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    content = build_test_page(rel_path, definition)
    with open(out_path, "w") as f:
        f.write(content)

    return rel_path


def collect_tags(tags, definition, rel_path):
    """Add tags from a test definition to the tags dict."""
    for scope in definition["scope"]:
        anchor = tag_anchor(scope)
        if anchor not in tags:
            tags[anchor] = {"label": scope, "pages": []}
        tags[anchor]["pages"].append(
            {"name": definition["name"], "path": rel_path + ".md"}
        )


def collect_table_row(test_tables, table_dirs, definition, rel_path):
    """Add a row to the appropriate index table."""
    for table_name in table_dirs:
        if rel_path.startswith(table_name):
            scope_links = ", ".join(
                "[%s](tags.md#%s)" % (s, tag_anchor(s)) for s in definition["scope"]
            )
            test_tables[table_name].append(
                {
                    "name": "[%s](%s.md)" % (definition["name"], rel_path),
                    "description": definition["description"],
                    "scope": scope_links,
                }
            )
            break


def generate_tags_page(docs_dir, tags):
    """Generate the tags index page."""
    path = os.path.join(docs_dir, "tags.md")
    lines = ["# Tags\n"]
    for anchor in sorted(tags):
        entry = tags[anchor]
        lines.append('<h2 id="%s">%s</h2>\n' % (anchor, entry["label"]))
        for page in sorted(entry["pages"], key=lambda p: p["name"]):
            lines.append("- [%s](%s)\n" % (page["name"], page["path"]))
        lines.append("")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def generate_index(docs_dir, table_dirs, test_tables, table_filename):
    """Generate the tests index table."""
    path = os.path.join(docs_dir, table_filename + ".md")
    lines = ["# Tests index\n"]
    for table_name in table_dirs:
        test_table = test_tables[table_name]
        lines.append('\n## <span class="tag">%s</span>\n' % table_name)
        lines.append("| Name | Description | Scope |")
        lines.append("| --- | --- | --- |")
        for row in sorted(test_table, key=lambda r: r["name"]):
            desc = row["description"].replace("\n", "")
            lines.append("| %s | %s | %s |" % (row["name"], desc, row["scope"]))
        lines.append("")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Generate markdown docs from YAML test definitions"
    )
    parser.add_argument(
        "--docs-dir", default=DOCS_DIR, help="Output directory (default: docs)"
    )
    parser.add_argument(
        "--table-dirs",
        nargs="+",
        default=TABLE_DIRS,
        help="Directories to scan for YAML files",
    )
    parser.add_argument(
        "--table-file",
        default=TABLE_FILENAME,
        help="Name of the index table file (without .md)",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Show warnings")
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING if args.verbose else logging.ERROR)

    test_tables = {name: [] for name in args.table_dirs}
    tags = {}
    generated = 0

    for table_dir in args.table_dirs:
        for root, dirs, filenames in os.walk(table_dir):
            for filename in filenames:
                if not filename.endswith(".yaml"):
                    continue
                filepath = os.path.join(root, filename)
                definition = parse_test_definition(filepath)
                if definition is None:
                    continue
                rel_path = write_test_page(filepath, args.docs_dir, definition)
                collect_tags(tags, definition, rel_path)
                collect_table_row(test_tables, args.table_dirs, definition, rel_path)
                generated += 1

    generate_index(args.docs_dir, args.table_dirs, test_tables, args.table_file)
    generate_tags_page(args.docs_dir, tags)
    print("Generated %d test doc(s) + index + tags (%d tags)" % (generated, len(tags)))


if __name__ == "__main__":
    main()
