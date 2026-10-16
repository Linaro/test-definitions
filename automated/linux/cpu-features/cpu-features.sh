#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Read the AArch64 ID registers as Linux presents them and decode them into
# Arm FEAT_* names (features.txt: register, field bits, minimum value, from
# the Arm ARM field definitions in the kernel's arch/arm64/tools/sysreg).
#
# Views: idregs-arm64 reads every register by MRS from EL0 on each CPU (the
# kernel's sanitised value, user-visible fields only) and by KVM_GET_ONE_REG
# on a fresh vCPU (sanitised value with hidden fields, minus what KVM does
# not give a guest), plus ID_AA64MMFR2_EL1.NV through KVM. A feature counts
# as present when either view shows it. MIDR/REVIDR per CPU, the hwcaps of
# /proc/cpuinfo and the kernel's "CPU features" lines are logged as well.
#
# Pointer authentication is also exercised (idregs pac): sign and
# authenticate with all five keys on every CPU, a wrong modifier must
# fault, PR_PAC_RESET_KEYS must change every key (EL1 writes the key
# registers, so EL3 does not trap them), and under KVM a guest with the
# ptrauth vCPU features signs with its own keys while one without takes
# UNDEFs. When FEAT_PAuth is not in the system-wide view, those cases
# skip and pac-not-exposed checks that no CPU signs.
#
# SVE, SVE2, SME and SME2 are checked the same way (idregs vec): the ID
# view, the hwcaps and /proc/cpuinfo must agree, and RDVL/RDSVL must run
# on every CPU exactly when the feature is present.
#
# Every FEAT_* in EXPECTED must be present (a feature the silicon has that
# the firmware hides fails); every one in ABSENT must not be.

# The awk programs are single-quoted on purpose.
# shellcheck disable=SC1091,SC2016
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

EXPECTED=""
ABSENT=""
IDREGS=""

usage() {
    echo "Usage: $0 [-e '<FEAT_* expected present>'] [-a '<FEAT_* expected absent>']" 1>&2
    echo "          [-t <idregs binary>]" 1>&2
    exit 1
}

while getopts "e:a:t:h" o; do
    case "$o" in
        e) EXPECTED="${OPTARG}" ;;
        a) ABSENT="${OPTARG}" ;;
        t) IDREGS="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"
REGS="${OUTPUT}/idregs.txt"
FEATS="${OUTPUT}/features.txt"

# idregs: given with -t, installed, or built here by make (idregs.c).
[ -n "${IDREGS}" ] || IDREGS="$(command -v idregs-arm64)"
if [ -z "${IDREGS}" ] && [ -f ./idregs-arm64 ]; then
    IDREGS="./idregs-arm64"
fi
if [ -z "${IDREGS}" ] && make -s CROSS_COMPILE= idregs-arm64 > "${OUTPUT}/idregs-build.log" 2>&1; then
    IDREGS="./idregs-arm64"
fi
if [ -z "${IDREGS}" ]; then
    info_msg "no idregs-arm64 (not installed, cannot be built here: see README.md)"
    report_skip "idregs-run"
    exit 0
fi
chmod +x "${IDREGS}" 2>/dev/null

echo "=== cpu-features: kernel $(uname -r)"
dmesg | grep -E "CPU: All CPU\(s\) started at|CPU features|SANITY CHECK|kvm \[[0-9]+\]|SME|SVE" | sed 's/^/dmesg: /'
for c in /sys/devices/system/cpu/cpu[0-9]*; do
    id="${c}/regs/identification"
    [ -d "${id}" ] || continue
    echo "sysfs ${c##*/} midr $(cat "${id}/midr_el1" 2>/dev/null) revidr $(cat "${id}/revidr_el1" 2>/dev/null)"
done
# One hwcaps line per distinct set, with the CPUs that report it.
awk -F': ' '/^processor/ { p = $2 } /^Features/ { s[$2] = s[$2] (s[$2] == "" ? "" : ",") p }
    END { for (f in s) print "hwcaps cpus " s[f] ": " f }' /proc/cpuinfo

if ! "${IDREGS}" > "${REGS}" 2>&1; then
    cat "${REGS}"
    report_fail "idregs-run"
    exit 0
fi
report_pass "idregs-run"
sed 's/^/idregs: /' "${REGS}"

# The EL0 view of the ID_AA64 registers is system-wide: it must be the same
# on every CPU.
if awk '$1 == "el0" && $3 ~ /^ID_AA64/ { k = $3; if (k in v && v[k] != $4) bad = 1; v[k] = $4 }
        END { exit bad }' "${REGS}"; then
    report_pass "el0-view-consistent"
else
    report_fail "el0-view-consistent"
fi

# Decode: per feature, present in the EL0 view, the KVM view, either; absent
# only when every view that can show its fields (features.txt columns 8
# and 9: field visible to EL0, field carried by KVM) shows none; otherwise
# unknown (e.g. hidden fields at EL1 without KVM).
awk -v table=features.txt '
# No "^": BusyBox awk may be built without math support.
function p2(n,    r) {
    r = 1
    while (n-- > 0)
        r *= 2
    return r
}
function bit(hex, b,    d) {
    d = index("0123456789abcdef", substr(hex, 16 - int(b / 4), 1)) - 1
    return int(d / p2(b % 4)) % 2
}
function field(hex, msb, lsb,    v, b) {
    v = 0
    for (b = msb; b >= lsb; b--)
        v = v * 2 + bit(hex, b)
    return v
}
function has(view, i,    hex, v) {
    hex = val[view, R[i]]
    if (hex == "")
        return 0
    v = field(hex, M[i], L[i])
    if (K[i] == "s" && v >= p2(M[i] - L[i]))
        v -= p2(M[i] - L[i] + 1)
    if (K[i] == "i" && v == 15)
        v = 0
    return v >= N[i]
}
BEGIN {
    while ((getline line < table) > 0) {
        if (line ~ /^#/ || line == "")
            continue
        split(line, w, " ")
        n++; F[n] = w[1]; R[n] = w[2]; M[n] = w[3]; L[n] = w[4]; K[n] = w[5]; N[n] = w[6]
        C[n] = w[7]; V[n] = w[8]; Q[n] = w[9]
    }
}
$1 == "el0" && $2 == "cpu0" && $4 ~ /^0x/ { val["el0", $3] = tolower(substr($4, 3)) }
$1 == "kvm" && $3 ~ /^0x/ { val["kvm", $2] = tolower(substr($3, 3)) }
$1 == "kvm-mmfr2-nv" { nv = $2 }
END {
    if (nv != "") {
        # Put the probed NV field into the KVM view of ID_AA64MMFR2_EL1.
        h = val["kvm", "ID_AA64MMFR2_EL1"]
        if (h != "")
            val["kvm", "ID_AA64MMFR2_EL1"] = substr(h, 1, 9) sprintf("%x", nv) substr(h, 11)
    }
    for (i = 1; i <= n; i++) {
        f = F[i]
        e = has("el0", i); k = has("kvm", i)
        if (e || k) present[f] = 1
        if (e) pe[f] = 1
        if (k) pk[f] = 1
        known = (V[i] == "v" && val["el0", R[i]] != "") || (val["kvm", R[i]] != "" && \
            (Q[i] == "k" || (R[i] == "ID_AA64MMFR2_EL1" && C[i] ~ /^NV>=/ && nv != "")))
        if (!known) unk[f] = 1
        if (!(f in cite)) order[++m] = f
        cite[f] = cite[f] (cite[f] == "" ? "" : "|") R[i] "." C[i]
    }
    for (j = 1; j <= m; j++) {
        f = order[j]
        printf "%s %s el0=%s kvm=%s %s\n", (f in present) ? "present" : (f in unk) ? "unknown" : "absent",
            f, (f in pe) ? "y" : "n", (f in pk) ? "y" : "n", cite[f]
    }
}' "${REGS}" > "${FEATS}"
sed 's/^/feature: /' "${FEATS}"
echo "features present: $(awk '$1 == "present" { printf "%s ", $2 }' "${FEATS}")"
echo "features unknown: $(awk '$1 == "unknown" { printf "%s ", $2 }' "${FEATS}")"

# Pointer authentication, used rather than read: idregs pac.
PAC="${OUTPUT}/pac.txt"
"${IDREGS}" pac > "${PAC}" 2>&1
sed 's/^/idregs: /' "${PAC}"
if grep -q "^present FEAT_PAuth " "${FEATS}"; then
    pauth=1
else
    pauth=0
fi
# pac_check <test case> <awk program over pac.txt that exits 0 on pass>
pac_check() {
    if awk "$2" "${PAC}"; then report_pass "$1"; else report_fail "$1"; fi
}
if [ "${pauth}" = 1 ]; then
    # Every CPU: each key signs (or the PAC happens to be zero) and
    # authenticates back; a wrong modifier faults (SIGILL with FEAT_FPAC,
    # SIGSEGV on the poisoned pointer without); same PACs on every CPU.
    pac_check pac-el0-roundtrip '$2 ~ /^cpu/ && $3 == "roundtrip" { bad = 1 }
        $2 ~ /^cpu/ && $4 == "sign" { n++; if ($8 == "auth-mismatch") bad = 1; if ($8 == "ok") signed++ }
        $2 ~ /^cpu/ && $3 == "APGA" && $6 != "ok" { bad = 1 }
        END { exit bad || !n || !signed }'
    pac_check pac-el0-wrong-modifier-faults '$2 ~ /^cpu/ && $4 == "corrupt" { n++; if ($5 != "signal" || ($6 != 4 && $6 != 11)) bad = 1 }
        END { exit bad || !n }'
    pac_check pac-el0-same-on-all-cpus '$2 ~ /^cpu/ && ($4 == "sign" || $3 == "APGA") { k = $3; v = $5; if (k in s && s[k] != v) bad = 1; s[k] = v }
        END { exit bad }'
    pac_check pac-el1-key-reset '$2 == "reset" && $4 != "changed" { bad = 1 } $2 == "reset" { n++ } END { exit bad || n != 5 }'
    pac_check pac-hwcaps '$2 == "hwcap" { exit !($4 == 1 && $6 == 1) }'
    if [ -e /dev/kvm ]; then
        # A guest with the ptrauth vCPU features programs its own keys
        # (MMU off, pointer 0x80000000): signs, authenticates back, a wrong
        # modifier does not authenticate (or takes an FPAC exception, EC 0x1c).
        pac_check pac-kvm-guest '$2 == "kvm-ptrauth" && $4 == "sign" && $5 == "0x0000000080000000" { bad = 1 }
            $2 == "kvm-ptrauth" && $4 == "auth" && $5 != "0x0000000080000000" { bad = 1 }
            $2 == "kvm-ptrauth" && $4 == "wrong" && $5 == "0x0000000080000000" { bad = 1 }
            $2 == "kvm-ptrauth" && $3 == "APGA" && $5 ~ /^0x00000000/ { bad = 1 }
            $2 == "kvm-ptrauth" && $3 == "done" { done = ($4 == 1); exc = $6; esr = $8 }
            END { exit bad || !done || (exc > 0 && esr !~ /^0x7[0-3]/) }'
        # Without them, KVM must keep the keys and PAC instructions from the
        # guest: UNDEF (EC 0) and nothing signed.
        pac_check pac-kvm-noptrauth-undef '$2 == "kvm-noptrauth" && $4 == "sign" && $5 != "0x0000000080000000" { bad = 1 }
            $2 == "kvm-noptrauth" && $3 == "done" { done = ($4 == 1); exc = $6; esr = $8 }
            END { exit bad || !done || exc == 0 || esr !~ /^0x2000000/ }'
    else
        report_skip pac-kvm-guest
        report_skip pac-kvm-noptrauth-undef
    fi
else
    for t in pac-el0-roundtrip pac-el0-wrong-modifier-faults pac-el0-same-on-all-cpus \
        pac-el1-key-reset pac-hwcaps pac-kvm-guest pac-kvm-noptrauth-undef; do
        report_skip "${t}"
    done
    # Not exposed to Linux: no hwcaps, and no CPU applies a PAC (a CPU
    # with FEAT_PAuth runs the instructions as NOPs, one without takes
    # SIGILL: the log above shows which, for asymmetric systems).
    pac_check pac-not-exposed '$2 == "hwcap" && ($4 != 0 || $6 != 0) { bad = 1 }
        $2 ~ /^cpu/ && $4 == "sign" && $8 == "ok" { bad = 1 } END { exit bad }'
fi

# SVE and SME used (idregs vec): the ID view, the hwcaps (/proc/cpuinfo
# sve, sve2, sme, sme2 come from the same bits) and RDVL/RDSVL on every CPU
# must agree. A feature in the ID registers whose instructions fault means
# a trap (CPTR_EL3.EZ/ESM, CPTR_EL2, CPACR_EL1); one that works without
# being in the ID view means Linux is not told about it.
VEC="${OUTPUT}/vec.txt"
"${IDREGS}" vec > "${VEC}" 2>&1
sed 's/^/idregs: /' "${VEC}"
has_feat() { grep -q "^present $1 " "${FEATS}" && echo 1 || echo 0; }
# vec_check <case> <FEAT> <hwcap name> [<instruction>]
vec_check() {
    id=$(has_feat "$2")
    hw=$(awk -v n="$3" '$2 == "hwcap" { for (i = 3; i < NF; i += 2) if ($i == n) print $(i + 1) }' "${VEC}")
    cpuinfo=0
    grep -q "^Features.* $3\( \|$\)" /proc/cpuinfo && cpuinfo=1
    ok=1
    [ "${id}" = "${hw}" ] && [ "${hw}" = "${cpuinfo}" ] || ok=0
    if [ -n "$4" ]; then
        # every CPU runs it when present, every CPU faults when absent
        if [ "${id}" = 1 ]; then
            awk -v x="$4" '$3 == x && !($4 == "exit" && $5 == 0) { bad = 1 } END { exit bad }' "${VEC}" || ok=0
        else
            awk -v x="$4" '$3 == x && $4 == "exit" && $5 == 0 { bad = 1 } END { exit bad }' "${VEC}" || ok=0
        fi
    fi
    info_msg "$1: id ${id} hwcap ${hw} cpuinfo ${cpuinfo}"
    if [ "${ok}" = 1 ]; then report_pass "$1"; else report_fail "$1"; fi
}
vec_check vec-sve-consistent FEAT_SVE sve rdvl
vec_check vec-sve2-consistent FEAT_SVE2 sve2
vec_check vec-sme-consistent FEAT_SME sme rdsvl
vec_check vec-sme2-consistent FEAT_SME2 sme2

# Fields the kernel itself clears from the EL0 view: with the "SSBS not
# fully self-synchronizing" erratum it hides SSBS from user space, so
# without the KVM view an absent SSBS says nothing about the firmware.
kernel_hidden=""
if dmesg | grep -q "SSBS not fully self-synchronizing" && ! grep -q "^kvm ID_AA64PFR1_EL1 0x" "${REGS}"; then
    kernel_hidden="FEAT_SSBS FEAT_SSBS2"
fi
for f in ${EXPECTED}; do
    if ! grep -q "^present ${f} " "${FEATS}" && echo " ${kernel_hidden} " | grep -q " ${f} "; then
        info_msg "${f}: hidden from EL0 by the kernel (SSBS erratum)"
        report_skip "present-${f}"
    elif grep -q "^present ${f} " "${FEATS}"; then
        report_pass "present-${f}"
    elif grep -q "^unknown ${f} " "${FEATS}"; then
        info_msg "${f}: no view here can show its fields"
        report_skip "present-${f}"
    elif grep -q " ${f} " "${FEATS}"; then
        report_fail "present-${f}"
    else
        info_msg "${f} is not in features.txt"
        report_fail "present-${f}"
    fi
done
for f in ${ABSENT}; do
    if grep -q "^present ${f} " "${FEATS}"; then
        report_fail "absent-${f}"
    elif grep -q "^absent ${f} " "${FEATS}"; then
        report_pass "absent-${f}"
    elif grep -q "^unknown ${f} " "${FEATS}"; then
        info_msg "${f}: no view here can show its fields"
        report_skip "absent-${f}"
    else
        info_msg "${f} is not in features.txt"
        report_fail "absent-${f}"
    fi
done
exit 0
