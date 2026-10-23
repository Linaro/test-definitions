#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Boot a Linux guest under KVM with kvmtool and check it end to end: it
# reaches userspace with the requested number of vCPUs (its init prints a
# "kvm-guest: ready" line with the vCPU count, kernel release and uptime),
# runs a command sent over its virtio console, and powers off, so that
# kvmtool exits 0. The time from the start of kvmtool to the ready line is
# the guest-boot measurement. kvmtool reads console input only from a
# terminal, so it runs on a pty that socat connects to the test.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

LKVM="lkvm"
KERNEL="/opt/kvm-guest/Image"
INITRD="/opt/kvm-guest/initramfs.cpio.gz"
VCPUS="2"
MEMORY="256"
TIMEOUT="60"

usage() {
    echo "Usage: $0 [-l <lkvm>] [-k <kernel>] [-i <initramfs>] [-c <vcpus>]" 1>&2
    echo "          [-m <memory MiB>] [-t <timeout s>]" 1>&2
    exit 1
}

while getopts "l:k:i:c:m:t:h" o; do
    case "$o" in
        l) LKVM="${OPTARG}" ;;
        k) KERNEL="${OPTARG}" ;;
        i) INITRD="${OPTARG}" ;;
        c) VCPUS="${OPTARG}" ;;
        m) MEMORY="${OPTARG}" ;;
        t) TIMEOUT="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

CASES="guest-boot guest-vcpus guest-command guest-shutdown"
CONSOLE="${OUTPUT}/console.log"
FIFO="${OUTPUT}/console.in"

# Centiseconds since boot
now() {
    tr -d . < /proc/uptime | cut -d ' ' -f 1
}

# wait_for <pattern>: until the guest console shows <pattern> (0), kvmtool
# exits (1) or TIMEOUT seconds pass (2)
wait_for() {
    local end
    end=$(($(now) + TIMEOUT * 100))
    while ! tr -d '\r' < "${CONSOLE}" | grep -q "$1"; do
        kill -0 "${pid}" 2> /dev/null || return 1
        [ "$(now)" -lt "${end}" ] || return 2
        sleep 0.1
    done
}

# wait_exit: until kvmtool exits (0) or TIMEOUT seconds pass (1)
wait_exit() {
    local end
    end=$(($(now) + TIMEOUT * 100))
    while kill -0 "${pid}" 2> /dev/null; do
        [ "$(now)" -lt "${end}" ] || return 1
        sleep 0.1
    done
}

fail_rest() {
    for c in ${CASES}; do
        report_fail "${c}"
    done
}

create_out_dir "${OUTPUT}"

if ! command -v "${LKVM}" > /dev/null || ! command -v socat > /dev/null ||
   [ ! -f "${KERNEL}" ] || [ ! -f "${INITRD}" ]; then
    info_msg "needs ${LKVM}, socat, ${KERNEL} and ${INITRD}"
    for c in ${CASES}; do
        report_skip "${c}"
    done
    exit 0
fi
# kvmtool keeps its control sockets in ${HOME}/.lkvm
[ -d "${HOME:-}" ] || export HOME=/tmp
ls -l /dev/kvm

VMM="${OUTPUT}/vmm.sh"
cat > "${VMM}" << EOF
#!/bin/sh
"${LKVM}" run --kernel "${KERNEL}" --initrd "${INITRD}" --cpus "${VCPUS}" \\
    --mem "${MEMORY}" --console virtio --network mode=none --params quiet
echo "kvm-guest: vmm exit status \$?"
EOF
chmod 755 "${VMM}"
mkfifo "${FIFO}"
# Held open read-write, so socat never sees the end of its input.
exec 3<> "${FIFO}"
start="$(now)"
socat STDIO "EXEC:${VMM},pty,setsid,ctty,stderr" < "${FIFO}" > "${CONSOLE}" 2>&1 &
pid=$!

wait_for "kvm-guest: ready"
rc=$?
ready="$(now)"
if [ "${rc}" -ne 0 ]; then
    [ "${rc}" -eq 2 ] && info_msg "no ready line in ${TIMEOUT} s" && kill "${pid}"
    wait "${pid}"
    cat "${CONSOLE}"
    fail_rest
    exit 0
fi
line="$(tr -d '\r' < "${CONSOLE}" | grep -m 1 "kvm-guest: ready")"
info_msg "${line}"
CASES="guest-vcpus guest-command guest-shutdown"
secs="$(((ready - start) / 100)).$(printf '%02d' $(((ready - start) % 100)))"
add_metric "guest-boot" "pass" "${secs}" "seconds"

vcpus="$(echo "${line}" | sed -n 's/.* vcpus=\([0-9]*\) .*/\1/p')"
if [ "${vcpus}" = "${VCPUS}" ]; then
    report_pass "guest-vcpus"
else
    info_msg "expected ${VCPUS} vCPUs, the guest has ${vcpus:-none}"
    report_fail "guest-vcpus"
fi

# The console echoes the command line; only a shell evaluating it prints 42.
# shellcheck disable=SC2016
echo 'echo "guest-command: $((6 * 7))"' >&3
if wait_for "^guest-command: 42"; then
    report_pass "guest-command"
else
    report_fail "guest-command"
fi

echo "poweroff -f" >&3
if ! wait_exit; then
    info_msg "kvmtool still running ${TIMEOUT} s after poweroff"
    kill "${pid}"
fi
wait "${pid}"
rc="$(tr -d '\r' < "${CONSOLE}" | sed -n 's/^kvm-guest: vmm exit status //p')"
info_msg "kvmtool exit status ${rc:-unknown}"
if [ "${rc}" = "0" ]; then
    report_pass "guest-shutdown"
else
    report_fail "guest-shutdown"
fi
exec 3>&-
cat "${CONSOLE}"
