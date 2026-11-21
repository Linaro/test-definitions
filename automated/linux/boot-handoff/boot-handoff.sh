#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Check the state the boot firmware hands over to Linux: the boot CPU, the
# number of CPUs brought up, the exception level every CPU entered the
# kernel at, KVM and its mode, the TEE driver and the PSCI CPU idle mode.
# Each check but the CPU count is skipped when its parameter is empty.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

BOOT_CPU=""
CPUS=""
EXCEPTION_LEVEL=""
KVM=""
TEE=""
PSCI_MODE=""

usage() {
    echo "Usage: $0 [-b <boot cpu mpidr>] [-c <cpus>] [-e <EL1|EL2>]" 1>&2
    echo "          [-k <any|vhe|nvhe|protected>] [-t <optee|any>] [-p <osi|pc>]" 1>&2
    exit 1
}

while getopts "b:c:e:k:t:p:h" o; do
    case "$o" in
        b) BOOT_CPU="${OPTARG}" ;;
        c) CPUS="${OPTARG}" ;;
        e) EXCEPTION_LEVEL="${OPTARG}" ;;
        k) KVM="${OPTARG}" ;;
        t) TEE="${OPTARG}" ;;
        p) PSCI_MODE="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"
DMESG="${OUTPUT}/dmesg.txt"
dmesg > "${DMESG}"
SYS_CPU=/sys/devices/system/cpu

# The boot CPU is the one the firmware started Linux on.
boot_cpu="$(sed -n 's/.*Booting Linux on physical CPU \(0x[0-9a-fA-F]*\).*/\1/p' "${DMESG}" | head -n 1)"
info_msg "boot CPU: ${boot_cpu:-unknown}"
if [ -z "${BOOT_CPU}" ]; then
    report_skip "boot-cpu"
elif [ -z "${boot_cpu}" ]; then
    info_msg "no 'Booting Linux on physical CPU' line in the kernel log"
    report_fail "boot-cpu"
elif [ "$(printf '%d' "${boot_cpu}")" -eq "$(printf '%d' "${BOOT_CPU}")" ]; then
    report_pass "boot-cpu"
else
    info_msg "expected boot CPU ${BOOT_CPU}"
    report_fail "boot-cpu"
fi

online="$(cat "${SYS_CPU}/online")"
present="$(cat "${SYS_CPU}/present")"
n_online="$(cpu_list_count "${online}")"
n_present="$(cpu_list_count "${present}")"
info_msg "CPUs online ${online} (${n_online}), present ${present} (${n_present})"
grep -E "smp: Brought up|SMP: Total of" "${DMESG}"
expected="${CPUS:-${n_present}}"
if [ "${n_online}" -eq "${expected}" ]; then
    add_metric "cpus-online" "pass" "${n_online}" "cpus"
else
    info_msg "expected ${expected} CPUs online"
    add_metric "cpus-online" "fail" "${n_online}" "cpus"
fi

# The kernel compares the exception level every CPU entered at.
if [ -z "${EXCEPTION_LEVEL}" ]; then
    report_skip "cpus-exception-level"
else
    grep -E "CPU: (All CPU\(s\) started at|CPUs started in inconsistent modes)" "${DMESG}"
    if grep -q "CPU: All CPU(s) started at ${EXCEPTION_LEVEL}" "${DMESG}"; then
        report_pass "cpus-exception-level"
    else
        info_msg "not all CPUs started at ${EXCEPTION_LEVEL}"
        report_fail "cpus-exception-level"
    fi
fi

if [ -z "${KVM}" ] || [ "${KVM}" = "none" ]; then
    report_skip "kvm-initialized"
    report_skip "kvm-device"
else
    grep -E "kvm \[[0-9]+\]: .*mode initialized successfully|kvm \[[0-9]+\]: .*error|kvm: " "${DMESG}"
    # arm64/kvm prints "kvm [N]: [Hyp |Protected ][n|h]VHE[+NV2] mode
    # initialized successfully".
    case "${KVM}" in
        vhe) mode="\]: VHE(\+NV2)? mode initialized successfully" ;;
        nvhe) mode="Hyp nVHE(\+NV2)? mode initialized successfully" ;;
        protected) mode="Protected [hn]VHE(\+NV2)? mode initialized successfully" ;;
        *) mode="mode initialized successfully" ;;
    esac
    if grep -E "kvm \[[0-9]+\]: " "${DMESG}" | grep -qE "${mode}"; then
        report_pass "kvm-initialized"
    else
        info_msg "no 'kvm: ${mode}' line in the kernel log"
        report_fail "kvm-initialized"
    fi
    if [ -c /dev/kvm ]; then
        report_pass "kvm-device"
    else
        report_fail "kvm-device"
    fi
fi

if [ -z "${TEE}" ] || [ "${TEE}" = "none" ]; then
    report_skip "tee-driver"
    report_skip "tee-device"
else
    grep -E "optee: |tee: " "${DMESG}"
    if [ "${TEE}" = "optee" ]; then
        if grep -q "optee: initialized driver" "${DMESG}"; then
            report_pass "tee-driver"
        else
            report_fail "tee-driver"
        fi
    else
        report_skip "tee-driver"
    fi
    if [ -c /dev/tee0 ]; then
        report_pass "tee-device"
    else
        report_fail "tee-device"
    fi
fi

# cpuidle-psci-domain reports the mode it set up the CPU PM domains in.
grep -E "psci: |CPU PM domain|OSI mode" "${DMESG}"
if [ -z "${PSCI_MODE}" ]; then
    report_skip "psci-cpu-pm-domain-mode"
else
    case "${PSCI_MODE}" in
        osi|OSI) mode="OSI" ;;
        *) mode="PC" ;;
    esac
    if grep -q "Initialized CPU PM domain topology using ${mode} mode" "${DMESG}"; then
        report_pass "psci-cpu-pm-domain-mode"
    else
        info_msg "CPU PM domains are not in ${mode} mode"
        report_fail "psci-cpu-pm-domain-mode"
    fi
fi
exit 0
