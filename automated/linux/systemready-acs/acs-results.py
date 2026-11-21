#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
"""Turn the results of an Arm SystemReady devicetree band ACS run into
test-definitions result lines, one per test.

The ACS parses its own logs with Arm's log parser (/usr/bin/log_parser,
run by the ACS init.sh at the end of the automated run) into
acs_results/acs_summary/acs_jsons/*.json; the SCT results there already
carry the edk2-test-parser verdicts (EBBR.yaml). This script reads those
JSON files only, so a result here is Arm's result for that test:

  acs       Arm's compliance verdict per ACS suite and overall
            (merged_results.json)
  sct       one case per UEFI SCT test (sct.json)
  bsa       one case per BSA rule, UEFI and Linux (bsa.json)
  fwts      one case per FWTS test (fwts.json)
  dt        one case per devicetree check: dt-validate and the DT kselftest
            (dt_validate.json, dt_kselftest.json)
  standalone  one case per check of the ACS Linux tools: capsule update,
            PSCI, SMBIOS, block devices, ethtool, network boot, runtime
            device mapping
  pfdi      one case per PFDI rule (pfdi.json)
  post-script  one case per check of Arm's systemready-scripts
            (post_script.json)

Writes <output>/result.txt (test case lines grouped with lava-test-set by
the ACS sub suite), one <case>.log per failing case with Arm's reasons,
and <output>/summary-<suite>.txt (counts and failing cases).
"""

import argparse
import json
import os
import re
import sys

JSONS = {
    "sct": ["sct.json"],
    "bsa": ["bsa.json"],
    "fwts": ["fwts.json"],
    "dt": ["dt_validate.json", "dt_kselftest.json"],
    "standalone": [
        "capsule_update.json",
        "psci.json",
        "smbios_check.json",
        "read_write_check_blk_devices.json",
        "ethtool_test.json",
        "network_boot.json",
        "runtime_dev_map.json",
    ],
    "pfdi": ["pfdi.json"],
    "post-script": ["post_script.json"],
}
SKIP_WORDS = (
    "SKIP",
    "NOT SUPPORTED",
    "NOT IMPLEMENTED",
    "NOT TESTED",
    "NOT RUN",
    "IGNORED",
    "KNOWN",
    "N/A",
    "NOT APPLICABLE",
    "UNSUPPORTED",
    "NOT EXECUTED",
    "NO TEST",
)
MAX_NAME = 96


def norm(result):
    """An ACS result string (PASSED, FAILED, SKIPPED, PASSED(*WITH
    WARNINGS), KNOWN U-BOOT LIMITATION, ...) as pass, fail, skip or
    unknown."""
    r = str(result or "").upper()
    if "FAIL" in r or "ABORT" in r:
        return "fail"
    if "PASS" in r or "WARN" in r:
        return "pass"
    if any(w in r for w in SKIP_WORDS):
        return "skip"
    return "unknown"


def from_counts(c):
    """A result from ACS counters ({"PASSED": n, "FAILED": n, ...}, or the
    totals of a summary). Warnings alone are not a pass: Arm does not count
    them as failures, so they are a skip."""

    def n(*keys):
        return sum(
            int(v)
            for k, v in c.items()
            if k.upper() in keys and str(v).lstrip("-").isdigit()
        )

    if n("FAILED", "ABORTED", "TOTAL_FAILED", "TOTAL_ABORTED"):
        return "fail"
    if n("PASSED", "TOTAL_PASSED"):
        return "pass"
    if n(
        "WARNINGS",
        "TOTAL_WARNINGS",
        "SKIPPED",
        "TOTAL_SKIPPED",
        "TOTAL_IGNORED",
        "NOT_SUPPORTED",
    ):
        return "skip"
    return "unknown"


def reasons(sub):
    """Reason strings recorded for a subtest."""
    out = []
    r = sub.get("sub_test_result")
    if isinstance(r, dict):
        for k in ("fail_reasons", "abort_reasons", "warning_reasons", "skip_reasons"):
            v = r.get(k) or []
            for x in v if isinstance(v, list) else [v]:
                x = " ".join(map(str, x)) if isinstance(x, list) else str(x)
                if x.strip() not in ("", "N/A"):
                    out.append(x)
    if sub.get("reason"):
        out.append(str(sub["reason"]))
    return out


def sub_result(sub):
    r = sub.get("sub_test_result")
    return from_counts(r) if isinstance(r, dict) else norm(r)


def combine(results):
    rs = set(results)
    if "fail" in rs:
        return "fail"
    if "pass" in rs:
        return "pass"
    if "skip" in rs:
        return "skip"
    return "unknown"


class Report:
    def __init__(self, out):
        self.out = out
        self.lines = []
        self.names = set()
        self.cases = []  # (set, name, result, details)
        self.cur_set = None

    def start_set(self, name):
        name = clean(name) or "other"
        if name != self.cur_set:
            if self.cur_set:
                self.lines.append("lava-test-set stop")
            self.lines.append("lava-test-set start %s" % name)
            self.cur_set = name

    def add(self, name, result, details=None):
        base = clean(name) or "unnamed"
        name, i = base, 2
        while name in self.names:
            suffix = "-%d" % i
            name = base[: MAX_NAME - len(suffix)] + suffix
            i += 1
        self.names.add(name)
        self.lines.append("%s %s" % (name, result))
        self.cases.append((self.cur_set, name, result, details or []))
        if result in ("fail", "unknown") and details:
            with open(os.path.join(self.out, name + ".log"), "w") as f:
                f.write("\n".join(details) + "\n")

    def write(self, suite):
        if self.cur_set:
            self.lines.append("lava-test-set stop")
        with open(os.path.join(self.out, "result.txt"), "a") as f:
            f.write("\n".join(self.lines) + ("\n" if self.lines else ""))
        count = {
            k: sum(1 for c in self.cases if c[2] == k)
            for k in ("pass", "fail", "skip", "unknown")
        }
        text = [
            "%s: %d pass, %d fail, %d skip, %d unknown"
            % (suite, count["pass"], count["fail"], count["skip"], count["unknown"])
        ]
        for st, name, result, details in self.cases:
            if result in ("fail", "unknown"):
                why = details[0] if details else ""
                text.append("  %s %s/%s: %s" % (result.upper(), st, name, why[:200]))
        with open(os.path.join(self.out, "summary-%s.txt" % suite), "w") as f:
            f.write("\n".join(text) + "\n")
        print("\n".join(text))


def clean(name):
    """A LAVA test case name: no spaces, at most MAX_NAME characters."""
    s = re.sub(r"[^A-Za-z0-9_.+-]+", "_", str(name)).strip("_.-")
    return s[:MAX_NAME]


def load(jdir, fname):
    p = os.path.join(jdir, fname)
    if not os.path.exists(p):
        return None
    with open(p, errors="replace") as f:
        return json.load(f)


def entries(data):
    if isinstance(data, dict):
        data = data.get("test_results", [])
    return [e for e in data or [] if isinstance(e, dict)]


def sub_details(subs):
    out = []
    for s in subs:
        r = sub_result(s)
        if r in ("fail", "unknown"):
            desc = s.get("sub_Test_Description") or s.get("sub_Test_Number") or ""
            why = "; ".join(reasons(s))
            raw = s.get("sub_test_result")
            if not isinstance(raw, dict):
                why = ("%s %s" % (raw, why)).strip()
            out.append(
                "%s: %s%s"
                % (r.upper(), str(desc).strip(), (" (%s)" % why) if why else "")
            )
    return out


def do_sct(rep, data):
    """One case per SCT test entry point. The edk2-test-parser verdicts
    (EBBR.yaml: IGNORED, KNOWN U-BOOT LIMITATION, ...) apply to the
    assertions and Arm re-counts them in test_case_summary, which decides;
    test_result is the raw SCT verdict unless an override for the whole
    test set it (then it carries a reason)."""
    for e in entries(data):
        rep.start_set(e.get("Test_suite") or "sct")
        subs = e.get("subtests") or []
        if e.get("reason") and e.get("test_result"):
            result = norm(e["test_result"])
        elif e.get("test_case_summary"):
            result = from_counts(e["test_case_summary"])
        elif subs:
            result = combine(sub_result(s) for s in subs)
        else:
            result = norm(e.get("test_result"))
        name = e.get("Test_case") or e.get("Test Entry Point GUID")
        sub = e.get("Sub_test_suite")
        if sub and sub != "Unknown":
            name = "%s.%s" % (sub, name)
        details = sub_details(subs)
        if e.get("reason"):
            details.insert(0, "%s (%s)" % (e.get("test_result"), e["reason"]))
        rep.add(name, result, details)


def do_rules(rep, data):
    """BSA and PFDI: one case per rule."""
    for e in entries(data):
        rep.start_set(e.get("Test_suite") or "rules")
        for tc in e.get("testcases") or []:
            name = str(tc.get("Test_case", "")).split(":")[0].strip()
            result = norm(tc.get("Test_result"))
            details = [
                "%s: %s" % (tc.get("Test_result"), tc.get("Test_case_description", ""))
            ]
            details += sub_details(tc.get("subtests") or [])
            if tc.get("reason"):
                details.append(str(tc["reason"]))
            rep.add(name or tc.get("Test_case_description"), result, details)


def do_fwts(rep, data):
    """One case per FWTS test, failing when one of its subtests fails."""
    rep.start_set("fwts")
    for e in entries(data):
        subs = e.get("subtests") or []
        result = (
            combine(sub_result(s) for s in subs)
            if subs
            else from_counts(e.get("test_suite_summary") or {})
        )
        rep.add(e.get("Test_suite"), result, sub_details(subs))


def do_subtests(rep, data, prefix=""):
    """Standalone checks: one case per subtest of each entry. A dt-validate
    subtest is one finding on one node, named by the node and the finding
    (fail: Arm's errors, such as a compatible without a schema; skip:
    schema warnings, which Arm does not count as failures)."""
    for e in entries(data):
        tc = e.get("Test_case") or e.get("Test_suite") or prefix
        rep.start_set(tc)
        for s in e.get("subtests") or []:
            desc = str(s.get("sub_Test_Description") or "").strip()
            num = str(s.get("sub_Test_Number") or "").strip()
            why = reasons(s)
            name = desc or num
            if tc == "dt_validate":
                node = "root" if desc in ("", "/") else desc
                name = "%s:%s" % (node, " ".join(why[0].split()) if why else num)
            rep.add(
                name, sub_result(s), ["%s: %s" % (sub_result(s).upper(), desc)] + why
            )


def do_acs(rep, data):
    """Arm's compliance verdict per ACS suite (merged_results.json)."""
    info = {}
    if isinstance(data, dict):
        info = (data.get("Suite_Name: acs_info") or {}).get("ACS Results Summary") or {}
    rep.start_set("compliance")
    for k, v in info.items():
        m = re.match(r"Suite_Name:\s*(\S+)\s*:\s*(.+?)_compliance$", k)
        if not m:
            continue
        tag, suite = m.group(1).lower(), m.group(2)
        v = str(v)
        if v.startswith("Compliant"):
            result = "pass"
        elif "not run" in v.lower() and tag != "mandatory":
            result = "skip"
        else:
            result = "fail"
        rep.add("%s-%s" % (tag, suite.lower()), result, ["%s: %s" % (suite, v)])
    overall = info.get("Overall Compliance Result")
    if overall is not None:
        rep.add(
            "overall-compliance",
            "pass" if str(overall).startswith("Compliant") else "fail",
            [str(overall)],
        )


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument(
        "--results",
        required=True,
        help="acs_results directory (holds acs_summary/acs_jsons)",
    )
    p.add_argument("--suite", required=True, choices=["acs"] + sorted(JSONS))
    p.add_argument("--output", required=True)
    a = p.parse_args()
    jdir = os.path.join(a.results, "acs_summary", "acs_jsons")
    rep = Report(a.output)
    if a.suite == "acs":
        data = load(jdir, "merged_results.json")
        if data is None:
            rep.add("acs-summary", "fail", ["no %s/merged_results.json" % jdir])
        else:
            do_acs(rep, data)
        rep.write(a.suite)
        return 0
    found = False
    for fname in JSONS[a.suite]:
        data = load(jdir, fname)
        if data is None:
            continue
        found = True
        if a.suite == "sct":
            do_sct(rep, data)
        elif a.suite in ("bsa", "pfdi"):
            do_rules(rep, data)
        elif a.suite == "fwts":
            do_fwts(rep, data)
        else:
            do_subtests(rep, data, os.path.splitext(fname)[0])
    if not found:
        # The ACS writes no JSON for a suite whose log is missing: the suite
        # did not run (or did not finish).
        rep.start_set("acs")
        rep.add(
            "%s-results" % a.suite,
            "skip" if a.suite in ("pfdi", "standalone") else "fail",
            ["none of %s in %s" % (", ".join(JSONS[a.suite]), jdir)],
        )
    rep.write(a.suite)
    return 0


if __name__ == "__main__":
    sys.exit(main())
