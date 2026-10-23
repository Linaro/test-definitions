#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Audio playback across a restart of the DSP that runs the audio path:
# play, crash the DSP through remoteproc debugfs while idle, wait for the DSP
# and the sound card to come back, play again; then crash it in the middle
# of a stream and check that the stream ends instead of hanging, the card
# comes back and plays. The mixer settings are applied before every
# playback, since a DSP restart recreates the card and its controls.
# With a capture PCM, each playback is followed by a recording that must
# deliver the requested number of frames and not be all zeros.
# Without the card the test is skipped; without the remoteproc or its
# debugfs crash file only the restart cases are skipped.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

CARD=""
PCM=""
MIXER=""
REMOTEPROC="adsp"
PLAY_SECONDS="2"
BUSY_SECONDS="10"
WAIT_SECONDS="30"
FORMAT="S16_LE"
RATE="48000"
CHANNELS="2"
CAPTURE_PCM=""
CAPTURE_MIXER=""
CAPTURE_CHANNELS="1"
CAPTURE_RATE="48000"

usage() {
    echo "Usage: $0 [-c <card id>] [-p <pcm name>] [-m '<control>=<value>;...']" 1>&2
    echo "          [-r <remoteproc>] [-d <play s>] [-b <busy play s>] [-w <wait s>]" 1>&2
    echo "          [-f <format>] [-R <rate>] [-C <channels>]" 1>&2
    echo "          [-P <capture pcm name>] [-M '<control>=<value>;...']" 1>&2
    echo "          [-N <capture channels>] [-S <capture rate>]" 1>&2
    exit 1
}

while getopts "c:p:m:r:d:b:w:f:R:C:P:M:N:S:h" o; do
    case "$o" in
        c) CARD="${OPTARG}" ;;
        p) PCM="${OPTARG}" ;;
        m) MIXER="${OPTARG}" ;;
        r) REMOTEPROC="${OPTARG}" ;;
        d) PLAY_SECONDS="${OPTARG}" ;;
        b) BUSY_SECONDS="${OPTARG}" ;;
        w) WAIT_SECONDS="${OPTARG}" ;;
        f) FORMAT="${OPTARG}" ;;
        R) RATE="${OPTARG}" ;;
        C) CHANNELS="${OPTARG}" ;;
        P) CAPTURE_PCM="${OPTARG}" ;;
        M) CAPTURE_MIXER="${OPTARG}" ;;
        N) CAPTURE_CHANNELS="${OPTARG}" ;;
        S) CAPTURE_RATE="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

# card_index: index of CARD (its id or name), or of the first card
card_index() {
    if [ -z "${CARD}" ]; then
        awk '/^ *[0-9]+ \[/ { print $1; exit }' /proc/asound/cards
    else
        awk -v c="${CARD}" '/^ *[0-9]+ \[/ {
            id = $2; sub(/^\[/, "", id); gsub(/[]: ]/, "", id)
            n = $0; sub(/.* - /, "", n)
            if (id == c || n == c) { print $1; exit } }' /proc/asound/cards
    fi
}

# pcm_device <card> [aplay|arecord] [name]: first device of that direction
# whose name matches (default: playback, PCM)
pcm_device() {
    "${2:-aplay}" -l 2>/dev/null | awk -v c="$1" -v p="${3-${PCM}}" '
        $1 == "card" && $2 == c ":" {
            d = $0; sub(/.*device /, "", d); sub(/:.*/, "", d)
            if (p == "" || index($0, ": " p " ") || index($0, ": " p "\t")) { print d; exit } }'
}

# since <marker>: kernel log lines after the marker line, or all of them
# without a marker or once it has left the buffer (log timestamps stop
# during suspend, /proc/uptime does not, so a time cannot mark the start)
since() {
    dmesg | awk -v m="$1" 'f { print; next } { b[++n] = $0 } m != "" && substr($0, length($0) - length(m) + 1) == m { f = 1 } END { if (!f) for (i = 1; i <= n; i++) print b[i] }'
}

controls() {
    amixer -c "$1" controls 2>/dev/null | wc -l
}

# mixer <card> [settings]: apply every <control>=<value> (default: MIXER)
mixer() {
    local rc=0
    local old_ifs="${IFS}"
    IFS=';'
    for s in ${2-${MIXER}}; do
        IFS="${old_ifs}"
        [ -n "${s}" ] || continue
        if ! amixer -c "$1" -q cset "name=${s%=*}" "${s##*=}"; then
            info_msg "cannot set '${s%=*}' to ${s##*=}"
            rc=1
        fi
        IFS=';'
    done
    IFS="${old_ifs}"
    return "${rc}"
}

# play <case> <seconds>: play silence on the PCM and check it completes
play() {
    local c
    local d
    c="$(card_index)"
    d="$(pcm_device "${c}")"
    if [ -z "${c}" ] || [ -z "${d}" ]; then
        info_msg "$1: no card or PCM"
        report_fail "$1"
        return
    fi
    if ! mixer "${c}"; then
        report_fail "$1-mixer"
    fi
    t0="$(date +%s)"
    aplay -D "hw:${c},${d}" -f "${FORMAT}" -r "${RATE}" -c "${CHANNELS}" -d "$2" /dev/zero > "${OUTPUT}/$1.log" 2>&1 &
    pid=$!
    i=0
    while kill -0 "${pid}" 2>/dev/null && [ "${i}" -lt $(($2 + 10)) ]; do
        sleep 1
        i=$((i + 1))
    done
    if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}"
        wait "${pid}"
        cat "${OUTPUT}/$1.log"
        info_msg "$1: aplay hw:${c},${d} still running after ${i} s"
        report_fail "$1"
        return
    fi
    wait "${pid}"
    rc=$?
    dt=$(($(date +%s) - t0))
    cat "${OUTPUT}/$1.log"
    if [ "${rc}" -eq 0 ] && [ "${dt}" -ge $(($2 - 1)) ] &&
       ! grep -qiE "error|underrun|xrun" "${OUTPUT}/$1.log"; then
        info_msg "$1: aplay hw:${c},${d} played $2 s in ${dt} s"
        report_pass "$1"
    else
        info_msg "$1: aplay hw:${c},${d} exited ${rc} after ${dt} s"
        report_fail "$1"
    fi
}

# sample_bytes: bytes per sample of FORMAT in a raw file
sample_bytes() {
    case "${FORMAT}" in
        S8|U8) echo 1 ;;
        S16_*|U16_*) echo 2 ;;
        S24_3*|U24_3*) echo 3 ;;
        *) echo 4 ;;
    esac
}

# record <case> <seconds>: record from CAPTURE_PCM and check that all the
# frames arrive and are not all zeros
record() {
    local c
    local d
    local f
    local want
    local got
    local nz
    c="$(card_index)"
    d="$(pcm_device "${c}" arecord "${CAPTURE_PCM}")"
    if [ -z "${c}" ] || [ -z "${d}" ]; then
        info_msg "$1: no card or capture PCM"
        report_fail "$1"
        return
    fi
    if ! mixer "${c}" "${CAPTURE_MIXER}"; then
        report_fail "$1-mixer"
    fi
    f="${OUTPUT}/$1.raw"
    rm -f "${f}"
    t0="$(date +%s)"
    arecord -D "plughw:${c},${d}" -f "${FORMAT}" -r "${CAPTURE_RATE}" -c "${CAPTURE_CHANNELS}" \
        -t raw -d "$2" "${f}" > "${OUTPUT}/$1.log" 2>&1 &
    pid=$!
    i=0
    while kill -0 "${pid}" 2>/dev/null && [ "${i}" -lt $(($2 + 10)) ]; do
        sleep 1
        i=$((i + 1))
    done
    if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}"
        wait "${pid}"
        cat "${OUTPUT}/$1.log"
        info_msg "$1: arecord plughw:${c},${d} still running after ${i} s"
        report_fail "$1"
        return
    fi
    wait "${pid}"
    rc=$?
    dt=$(($(date +%s) - t0))
    cat "${OUTPUT}/$1.log"
    want=$((CAPTURE_RATE * CAPTURE_CHANNELS * $(sample_bytes) * $2))
    got="$(wc -c < "${f}" 2>/dev/null || echo 0)"
    nz="$(tr -d '\000' < "${f}" 2>/dev/null | wc -c)"
    info_msg "$1: arecord plughw:${c},${d} exit ${rc} after ${dt} s, ${got} of ${want} bytes, ${nz} non-zero"
    if [ "${rc}" -eq 0 ] && [ "${got}" -ge "${want}" ] && [ "${nz}" -gt 0 ] &&
       ! grep -qiE "error|overrun|xrun" "${OUTPUT}/$1.log"; then
        report_pass "$1"
    else
        report_fail "$1"
    fi
}

# capture <case> <seconds>: record, when there is a capture PCM
capture() {
    [ -z "${CAPTURE_PCM}" ] || record "$@"
}

# skip_capture <case>: skip a capture case, when there is a capture PCM
skip_capture() {
    [ -z "${CAPTURE_PCM}" ] || report_skip "$1"
}

# restart <case>: crash the remoteproc, wait for it and for the card
restart() {
    local gone=0
    local i=0
    echo 1 > "${RPROC_DEBUG}/crash"
    while [ "${i}" -lt "${WAIT_SECONDS}" ]; do
        sleep 1
        i=$((i + 1))
        [ -z "$(card_index)" ] && gone=1
        if [ "$(cat "${RPROC}/state")" = running ] && [ "${gone}" -eq 1 ] &&
           [ -n "$(card_index)" ]; then
            info_msg "$1: ${REMOTEPROC} running and card back after ${i} s"
            add_metric "$1" "pass" "${i}" "s"
            return 0
        fi
    done
    info_msg "$1: after ${i} s ${REMOTEPROC} is $(cat "${RPROC}/state"), card seen absent: ${gone}, card: '$(card_index)'"
    report_fail "$1"
    return 1
}

# kernel_clean <case> <marker>: no abort, WARN or BUG since the marker
kernel_clean() {
    local n
    n="$(since "$2" | grep -cE "WARNING:|BUG:|Oops|Internal error|Unable to handle|external abort")"
    since "$2" | grep -E "WARNING:|BUG:|Oops|Internal error|Unable to handle|external abort" | head -n 10
    if [ "${n}" -eq 0 ]; then
        report_pass "$1"
    else
        add_metric "$1" "fail" "${n}" "lines"
    fi
}

create_out_dir "${OUTPUT}"
mount -t debugfs none /sys/kernel/debug 2>/dev/null
cat /proc/asound/cards
aplay -l
[ -z "${CAPTURE_PCM}" ] || arecord -l

if ! command -v aplay > /dev/null || ! command -v amixer > /dev/null ||
   { [ -n "${CAPTURE_PCM}" ] && ! command -v arecord > /dev/null; }; then
    warn_msg "aplay, arecord or amixer is not installed"
    report_skip "alsa-card"
    exit 0
fi
c="$(card_index)"
if [ -z "${c}" ]; then
    info_msg "no sound card ${CARD}"
    report_skip "alsa-card"
    exit 0
fi
report_pass "alsa-card"
# Follow this card by its id: with another card present, "the first card"
# is a different one while this card is gone during a DSP restart.
CARD="$(cat "/proc/asound/card${c}/id")"
n_controls="$(controls "${c}")"
info_msg "card ${c}: ${n_controls} controls, PCM device $(pcm_device "${c}")"

play "playback" "${PLAY_SECONDS}"
capture "capture" "${PLAY_SECONDS}"

RPROC="$(remoteproc_dirs "${REMOTEPROC}" | head -n 1)"
RPROC_DEBUG="/sys/kernel/debug/remoteproc/$(basename "${RPROC:-none}")"
if [ -z "${RPROC}" ] || [ ! -w "${RPROC_DEBUG}/crash" ]; then
    info_msg "no remoteproc ${REMOTEPROC} or no debugfs crash file"
    for t in dsp-restart-idle controls-after-restart playback-after-restart \
             dsp-restart-during-playback stream-ends-after-restart \
             playback-after-busy-restart kernel-clean-after-restart; do
        report_skip "${t}"
    done
    skip_capture "capture-after-restart"
    skip_capture "capture-after-busy-restart"
    exit 0
fi
info_msg "${REMOTEPROC} is $(basename "${RPROC}"), recovery $(cat "${RPROC_DEBUG}/recovery" 2>/dev/null)"

marker="alsa-dsp-restart: start $$"
echo "${marker}" 2>/dev/null > /dev/kmsg || marker=""
if restart "dsp-restart-idle"; then
    n="$(controls "$(card_index)")"
    if [ "${n}" -eq "${n_controls}" ]; then
        add_metric "controls-after-restart" "pass" "${n}" "controls"
    else
        info_msg "${n} controls after the restart, ${n_controls} before"
        add_metric "controls-after-restart" "fail" "${n}" "controls"
    fi
    play "playback-after-restart" "${PLAY_SECONDS}"
    capture "capture-after-restart" "${PLAY_SECONDS}"
else
    report_skip "controls-after-restart"
    report_skip "playback-after-restart"
    skip_capture "capture-after-restart"
fi

# Crash the DSP two seconds into a longer stream.
c="$(card_index)"
d="$(pcm_device "${c}")"
mixer "${c}"
aplay -D "hw:${c},${d}" -f "${FORMAT}" -r "${RATE}" -c "${CHANNELS}" -d "${BUSY_SECONDS}" /dev/zero > "${OUTPUT}/busy.log" 2>&1 &
bpid=$!
sleep 2
if restart "dsp-restart-during-playback"; then
    i=0
    while kill -0 "${bpid}" 2>/dev/null && [ "${i}" -lt $((BUSY_SECONDS + 5)) ]; do
        sleep 1
        i=$((i + 1))
    done
    if kill -0 "${bpid}" 2>/dev/null; then
        kill "${bpid}"
        report_fail "stream-ends-after-restart"
    else
        wait "${bpid}"
        info_msg "aplay ended after the restart (exit $?)"
        report_pass "stream-ends-after-restart"
    fi
    cat "${OUTPUT}/busy.log"
    play "playback-after-busy-restart" "${PLAY_SECONDS}"
    capture "capture-after-busy-restart" "${PLAY_SECONDS}"
else
    kill "${bpid}" 2>/dev/null
    report_skip "stream-ends-after-restart"
    report_skip "playback-after-busy-restart"
    skip_capture "capture-after-busy-restart"
fi
kernel_clean "kernel-clean-after-restart" "${marker}"
exit 0
