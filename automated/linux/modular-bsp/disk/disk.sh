#!/bin/bash
#
# disk.sh
#
# Advantech BSP QA – Disk checks
# Ported from test_disk() in qa/test_board.sh
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${DISK_COUNT:=1}"
: "${DISK_ROOTFS_MOUNT:=}"

# ─── Rootfs mount check ───────────────────────────────────────────────────────

if [ -n "${DISK_ROOTFS_MOUNT}" ]; then
    mp=$(mount | grep "on / type" | awk '{print $1}')
    mm=$(mount | grep "on / type" | awk -F'(' '{print $2}' | awk -F, '{print $1}')
    mfound=0

    for entry in ${DISK_ROOTFS_MOUNT}; do
        mip=$(echo "${entry}" | awk -F: '{print $1}')
        mim=$(echo "${entry}" | awk -F: '{print $2}')

        if [ "${mip}" = "${mp}" ]; then
            mfound=1
            if [ "${mm}" = "${mim}" ]; then
                report_pass "L-DISK-ROOTFS-MODE"
            else
                report_fail "L-DISK-ROOTFS-MODE"
            fi
            break
        fi
    done

    if [ "${mfound}" -eq 1 ]; then
        report_pass "L-DISK-ROOTFS-FOUND"
    else
        report_fail "L-DISK-ROOTFS-FOUND"
    fi
fi

# ─── Per-disk checks ──────────────────────────────────────────────────────────

file_read_test() {
    local dev="$1" type="$2" bsz="$3" cnt="$4" minsp="$5" req_id="$6"
    local tmpf
    tmpf=$(mktemp /tmp/disk_read_test.XXXXXX)
    drop_caches
    local out
    out=$(dd if="${dev}" of="${tmpf}" bs="${bsz}" count="${cnt}" \
             iflag=direct 2>&1 | tail -1)
    local sp
    sp=$(echo "${out}" | awk '{print $(NF-1)}')
    local unit
    unit=$(echo "${out}" | awk '{print $NF}')
    rm -f "${tmpf}"
    # Normalise to MB/s
    local sp_mb
    case "${unit}" in
    GB/s) sp_mb=$(awk "BEGIN{printf \"%d\", ${sp}*1024}") ;;
    MB/s) sp_mb=$(awk "BEGIN{printf \"%d\", ${sp}}") ;;
    kB/s) sp_mb=$(awk "BEGIN{printf \"%d\", ${sp}/1024}") ;;
    *)    sp_mb=0 ;;
    esac
    if [ "${sp_mb}" -ge "${minsp}" ] 2>/dev/null; then
        report_metric "${req_id}" "pass" "${sp_mb}" "MB/s"
    else
        report_metric "${req_id}" "fail" "${sp_mb}" "MB/s"
    fi
}

fs_write_test() {
    local dev="$1" type="$2" bsz="$3" cnt="$4" minsp="$5" req_id="$6"
    local mnt tmpf
    mnt=$(mktemp -d /tmp/disk_write_test.XXXXXX)
    # Find a writable partition on the device
    local part
    part=$(lsblk -no NAME,TYPE "${dev}" 2>/dev/null | awk '/part/{print "/dev/"$1}' | head -1)
    [ -n "${part}" ] || part="${dev}"
    if ! mount -o rw "${part}" "${mnt}" 2>/dev/null; then
        report_skip "${req_id}"
        rmdir "${mnt}"
        return
    fi
    tmpf="${mnt}/.write_test_$$"
    drop_caches
    local out
    out=$(dd if=/dev/urandom of="${tmpf}" bs="${bsz}" count="${cnt}" \
             oflag=sync 2>&1 | tail -1)
    rm -f "${tmpf}"
    umount "${mnt}" 2>/dev/null
    rmdir "${mnt}"
    local sp
    sp=$(echo "${out}" | awk '{print $(NF-1)}')
    local unit
    unit=$(echo "${out}" | awk '{print $NF}')
    local sp_mb
    case "${unit}" in
    GB/s) sp_mb=$(awk "BEGIN{printf \"%d\", ${sp}*1024}") ;;
    MB/s) sp_mb=$(awk "BEGIN{printf \"%d\", ${sp}}") ;;
    kB/s) sp_mb=$(awk "BEGIN{printf \"%d\", ${sp}/1024}") ;;
    *)    sp_mb=0 ;;
    esac
    if [ "${sp_mb}" -ge "${minsp}" ] 2>/dev/null; then
        report_metric "${req_id}" "pass" "${sp_mb}" "MB/s"
    else
        report_metric "${req_id}" "fail" "${sp_mb}" "MB/s"
    fi
}

n=0
while [ "${n}" -lt "${DISK_COUNT}" ]; do
    eval "dev=\${DISK${n}_DEV}"
    eval "dtype=\${DISK${n}_TYPE}"
    eval "sectors=\${DISK${n}_SECTORS:-0}"
    eval "min_rs=\${DISK${n}_MIN_RS:-0}"
    eval "min_ws=\${DISK${n}_MIN_WS:-0}"

    req_dev="L-DISK-DEV-disk${n}"
    dn=$(basename "${dev}")

    if ! disk_exists "${dev}"; then
        warn_msg "disk${n}: not found: ${dev}"
        n=$((n + 1))
        continue
    fi

    if chk_rw_bdev "${dev}"; then
        report_pass "${req_dev}"
    else
        report_fail "${req_dev}"
        n=$((n + 1))
        continue
    fi

    # Sector count
    if [ "${sectors}" -gt 0 ] 2>/dev/null; then
        rs=$(cat "/sys/block/${dn}/size" 2>/dev/null)
        rs=$((rs + 0))
        if [ "${rs}" -eq "${sectors}" ]; then
            report_pass "L-DISK-SECTORS-disk${n}"
        else
            report_fail "L-DISK-SECTORS-disk${n}"
        fi
    fi

    # Disk type
    tdt=$(disk_type "${dev}")
    if [ "${tdt}" = "${dtype}" ]; then
        report_pass "L-DISK-TYPE-disk${n}"
    else
        report_fail "L-DISK-TYPE-disk${n}"
    fi

    # MMC extended CSD
    if [ "${dtype}" = "MMC" ]; then
        if chk_cmd mmc; then
            if mmc extcsd read "${dev}" >/dev/null 2>&1; then
                report_pass "L-DISK-EXTCSD-READABLE-disk${n}"
            else
                report_fail "L-DISK-EXTCSD-READABLE-disk${n}"
            fi
        else
            report_skip "L-DISK-EXTCSD-READABLE-disk${n}"
        fi
    fi

    # Read throughput (functional)
    if [ "${min_rs}" -gt 0 ] 2>/dev/null; then
        file_read_test "${dev}" "${dtype}" 100000 1000 "${min_rs}" \
            "L-DISK-READ-THROUGHPUT-F-disk${n}"
    fi

    # Write throughput (functional)
    if [ "${min_ws}" -gt 0 ] 2>/dev/null; then
        fs_write_test "${dev}" "${dtype}" 100000 1000 "${min_ws}" \
            "L-DISK-WRITE-THROUGHPUT-F-disk${n}"
    fi

    n=$((n + 1))
done
