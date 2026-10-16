#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
"""gen-feats.py <arch/arm64/tools/sysreg> <arch/arm64/kernel/cpufeature.c>
              <feats.src> > features.txt

Resolves each "FEAT_X REG.FIELD>=VALUE" of feats.src against the kernel's
sysreg description (field bit range, signedness, enum value) into the line
format the target decoder reads:

    FEAT_X REG MSB LSB u|s|i MIN FIELD>=LABEL EL0 KVM

EL0 is v when the kernel shows the field to user space (FTR_VISIBLE in
cpufeature.c; an MRS from EL0 reads it), h when it hides it (EL0 reads the
safe value). KVM is k when KVM_GET_ONE_REG of a plain vCPU carries the
host value, m when KVM masks or limits the field (KVM_MASKED below, from
arch/arm64/kvm/sys_regs.c and measured on SM8750: raw EL2 values against
the KVM view). A feature absent from every view that can show its field is
absent; otherwise it is unknown.
"""

import re
import sys


def parse(path):
    regs, cur, field = {}, None, None
    for line in open(path):
        w = line.split()
        if not w or w[0].startswith("#"):
            continue
        if w[0] == "Sysreg":
            cur = regs.setdefault(w[1], {})
        elif w[0] == "EndSysreg":
            cur = None
        elif cur is not None and w[0] in (
            "UnsignedEnum",
            "SignedEnum",
            "Enum",
            "Field",
        ):
            msb, lsb = (
                (int(x) for x in w[1].split(":")) if ":" in w[1] else (int(w[1]),) * 2
            )
            field = cur[w[2]] = {
                "msb": msb,
                "lsb": lsb,
                "signed": w[0] == "SignedEnum",
                "enum": {},
            }
        elif cur is not None and field is not None and re.match(r"0b[01]+$", w[0]):
            field["enum"][w[1]] = int(w[0], 2)
        elif w[0] == "EndEnum":
            field = None
    return regs


# Fields KVM hides from a plain vCPU or caps (sys_regs.c sanitise_*,
# __kvm_read_sanitised_id_reg); "*" is the whole register.
KVM_MASKED = {
    "ID_AA64PFR0_EL1": {"SVE", "AMU", "MPAM", "RME", "CSV2", "CSV3", "GIC"},
    "ID_AA64PFR1_EL1": {
        "SME",
        "MTE",
        "MTE_frac",
        "RNDR_trap",
        "NMI",
        "GCS",
        "THE",
        "MTEX",
        "PFAR",
        "MPAM_frac",
        "RAS_frac",
        "DF2",
    },
    "ID_AA64PFR2_EL1": {"*"},
    "ID_AA64ZFR0_EL1": {"*"},
    "ID_AA64SMFR0_EL1": {"*"},
    "ID_AA64FPFR0_EL1": {"*"},
    "ID_AA64DFR1_EL1": {"*"},
    "ID_AA64MMFR4_EL1": {"*"},
    "ID_AA64DFR0_EL1": {
        "PMSVer",
        "BRBE",
        "PMUVer",
        "DebugVer",
        "TraceVer",
        "TraceFilt",
        "TraceBuffer",
        "ExtTrcBuff",
        "MTPMU",
        "SEBEP",
        "HPMN0",
    },
    "ID_AA64ISAR2_EL1": {"WFxT"},
    "ID_AA64MMFR2_EL1": {"NV", "CCIDX"},
}
KVM_SHOWN = {
    "ID_AA64ISAR3_EL1": {"FPRCVT", "LSFE", "FAMINMAX", "LSUI"},
    "ID_AA64MMFR3_EL1": {"TCRX", "SCTLRX", "S1POE", "S1PIE"},
}


def kvm_col(reg, fld):
    if reg in KVM_SHOWN:
        return "k" if fld in KVM_SHOWN[reg] else "m"
    m = KVM_MASKED.get(reg, set())
    return "m" if "*" in m or fld in m else "k"


def visible(path):
    src = open(path).read()
    return set(
        re.findall(
            r"ARM64_FTR_BITS\(\s*FTR_VISIBLE\w*(?:\([^)]*\))?\s*,\s*\w+\s*,"
            r"\s*\w+\s*,\s*(ID_AA64\w+?_EL1)_(\w+)_SHIFT",
            src,
        )
    )


# Unsigned fields where 0b1111 means IMPLEMENTATION DEFINED, not a higher
# version: the decoder reads them as 0.
IMPDEF = {("ID_AA64DFR0_EL1", "PMUVer")}
regs = parse(sys.argv[1])
vis = visible(sys.argv[2])
bad = 0
for line in open(sys.argv[3]):
    line = line.split("#")[0].split()
    if not line:
        continue
    feat, cond = line
    m = re.match(r"(\w+)\.(\w+)>=(\w+)$", cond)
    reg, fld, val = m.groups()
    f = regs.get(reg, {}).get(fld)
    if f is None:
        print("%s: no field %s.%s" % (feat, reg, fld), file=sys.stderr)
        bad = 1
        continue
    if val in f["enum"]:
        n = f["enum"][val]
    elif re.match(r"\d+$", val):
        n = int(val)
    else:
        print(
            "%s: %s.%s has no value %s (%s)" % (feat, reg, fld, val, sorted(f["enum"])),
            file=sys.stderr,
        )
        bad = 1
        continue
    print(
        "%-20s %-17s %2d %2d %s %2d %-24s %s %s"
        % (
            feat,
            reg,
            f["msb"],
            f["lsb"],
            "s" if f["signed"] else ("i" if (reg, fld) in IMPDEF else "u"),
            n,
            "%s>=%s" % (fld, val),
            "v" if (reg, fld) in vis else "h",
            kvm_col(reg, fld),
        )
    )
sys.exit(bad)
