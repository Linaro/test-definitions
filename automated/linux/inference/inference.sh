#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 Qualcomm Technologies, Inc. and/or its subsidiaries.
#
# Image classification on each processing unit of the board with one model
# and one set of inputs, checked and timed the same way on every unit:
#   - every image's top-1 is its expected class;
#   - latency per inference (mean, p50, p90 over the timed runs, after
#     warm-up), reported as measurements so that two builds compare by
#     differencing them;
#   - each accelerator agrees with the CPU running the same runtime (same
#     top-1, logit cosine of at least MIN_COSINE), the HTP with the QAIRT
#     x86 HTP simulation of its Hexagon architecture within MAX_HOST_DIFF,
#     and the TensorFlow Lite CPU run with the x86 LiteRT run within
#     MAX_TFLITE_DIFF;
#   - a comparison table of all units at the end of the log.
#
# PUS lists what the board has, one entry per unit and runtime:
#   cpu:qnn                      Qualcomm AI Runtime (QAIRT) QNN CPU backend
#   npu<N>:qnn-htp:<arch>:<device id>:<remoteproc>
#                                QNN HTP backend on the Hexagon NSP <N>
#                                (QNN device id) behind <remoteproc>
#   npu<N>:qnn-dsp:<arch>:<device id>:<remoteproc>
#                                QNN DSP backend on a Hexagon DSP with HVX
#                                and no HTP (v66), behind <remoteproc>; the
#                                8-bit model, checked against the QNN CPU
#                                backend (QAIRT has no x86 DSP simulation)
#   cpu:tflite[:<threads>]       TensorFlow Lite with XNNPACK on the CPU
#                                (default 4 threads), with tflite-run
#   gpu:tflite-gpu[:fp16|fp32]   TensorFlow Lite GPU delegate (OpenCL),
#                                fp16 (default) or fp32 arithmetic; compared
#                                with cpu:tflite, which must come first
# ABSENT lists the units the board does not have, "<pu>=<reason>;...":
# their cases are reported as skip with the reason.
#
# The inputs are the job's: QAIRT_ZIP is the QAIRT SDK zip as Qualcomm
# publishes it (its license does not allow redistributing it on its own),
# checked against QAIRT_SHA256; the test extracts only what it runs, the
# Hexagon skels included. MODEL_DIR is the model bundle (README.md: DLCs,
# the TensorFlow Lite model, inputs, expected classes, x86 references,
# MANIFEST.sha256). tflite-run (tflite-run.cc) runs the TensorFlow Lite
# model; when it is not installed and a compiler and the TensorFlow Lite
# headers are, it is built here. Without the zip, the model or tflite-run,
# the cases that need them are skipped with the reason.
#
# NEGATIVE=htp-down stops the remoteproc of each NSP or DSP entry before its
# run (and starts it again afterwards), so its cases must fail; NEGATIVE=gpu-down hides the
# OpenCL platforms from the GPU entries (OCL_ICD_VENDORS on an empty
# directory), so their cases must fail; NEGATIVE=wrong-class rotates the
# expected classes, so every top-1 case must fail.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

PUS="cpu:qnn"
ABSENT=""
QAIRT_ZIP=""
QAIRT_SHA256=""
QAIRT_ROOT="qairt/2.42.0.251225"
QNN_TARGET="aarch64-oe-linux-gcc11.2"
MODEL_DIR=""
MIN_COSINE="0.98"
MAX_HOST_DIFF="0.5"
MAX_TFLITE_DIFF="0.01"
WARMUP="5"
RUNS="50"
NEGATIVE=""
# Seconds one qnn-net-run or tflite-run may take: a hung DSP must not hold
# the job until its timeout, and a stopped remoteproc must be restarted.
RUN_TIMEOUT=300
WORK="${WORK:-/tmp/inference}"

usage() {
    echo "Usage: $0 [-p '<pu>:<runtime>[:...] ...'] [-a '<pu>=<reason>;...']" \
         "[-z <qairt zip>] [-s <zip sha256>] [-r <zip root>] [-m <model dir>]" \
         "[-c <min cosine>] [-x <max host diff>] [-y <max tflite host diff>]" \
         "[-w <warm-up runs>] [-l <timed runs>] [-n htp-down|gpu-down|wrong-class]" \
         "[-t <QAIRT target>]" 1>&2
    exit 1
}

while getopts "p:a:z:s:r:m:c:x:y:w:l:n:t:h" o; do
    case "$o" in
        p) PUS="${OPTARG}" ;;
        a) ABSENT="${OPTARG}" ;;
        z) QAIRT_ZIP="${OPTARG}" ;;
        s) QAIRT_SHA256="${OPTARG}" ;;
        r) QAIRT_ROOT="${OPTARG}" ;;
        m) MODEL_DIR="${OPTARG}" ;;
        c) MIN_COSINE="${OPTARG}" ;;
        x) MAX_HOST_DIFF="${OPTARG}" ;;
        y) MAX_TFLITE_DIFF="${OPTARG}" ;;
        w) WARMUP="${OPTARG}" ;;
        l) RUNS="${OPTARG}" ;;
        n) NEGATIVE="${OPTARG}" ;;
        t) QNN_TARGET="${OPTARG}" ;;
        h|*) usage ;;
    esac
done

create_out_dir "${OUTPUT}"
TIMEOUT_CMD=""
command -v timeout > /dev/null && TIMEOUT_CMD="timeout ${RUN_TIMEOUT}"

# tflite-run: installed, or built from tflite-run.cc against the installed
# TensorFlow Lite.
TFLITE_RUN="$(command -v tflite-run)"
if [ -z "${TFLITE_RUN}" ] && echo "${PUS}" | grep -q ":tflite"; then
    if make -s tflite-run > "${OUTPUT}/tflite-run-build.log" 2>&1; then
        TFLITE_RUN="$(pwd)/tflite-run"
    else
        info_msg "tflite-run is not installed and does not build here:"
        tail -n 5 "${OUTPUT}/tflite-run-build.log"
    fi
fi
rm -rf "${WORK}"
mkdir -p "${WORK}"
TABLE="${WORK}/table.txt"
: > "${TABLE}"

# cases <pu> <runtime>: the cases of one entry
cases() {
    case "$2" in
        qnn) echo "$1-qnn-run $1-qnn-top1 $1-qnn-latency $1-qnn-latency-p50 $1-qnn-latency-p90" ;;
        qnn-htp) echo "$1-qnn-htp-ready $1-qnn-htp-run $1-qnn-htp-top1 $1-qnn-htp-vs-cpu" \
                      "$1-qnn-htp-vs-host $1-qnn-htp-latency $1-qnn-htp-latency-p50" \
                      "$1-qnn-htp-latency-p90 $1-qnn-htp-speedup" ;;
        qnn-dsp) echo "$1-qnn-dsp-ready $1-qnn-dsp-run $1-qnn-dsp-top1 $1-qnn-dsp-vs-cpu" \
                      "$1-qnn-dsp-latency $1-qnn-dsp-latency-p50 $1-qnn-dsp-latency-p90" \
                      "$1-qnn-dsp-speedup" ;;
        tflite) echo "$1-tflite-run $1-tflite-top1 $1-tflite-vs-host $1-tflite-latency" \
                     "$1-tflite-latency-p50 $1-tflite-latency-p90" ;;
        tflite-gpu) echo "$1-tflite-gpu-ready $1-tflite-gpu-run $1-tflite-gpu-top1" \
                         "$1-tflite-gpu-vs-cpu $1-tflite-gpu-latency" \
                         "$1-tflite-gpu-latency-p50 $1-tflite-gpu-latency-p90" ;;
    esac
}

# skip_entry <entry> <reason>
skip_entry() {
    pu=${1%%:*}; rest=${1#*:}; rt=${rest%%:*}
    info_msg "${pu} ${rt}: skipped, $2"
    for c in $(cases "${pu}" "${rt}"); do
        report_skip "$c"
    done
    printf "%-6s %-10s %-8s %10s %10s %10s  %s\n" "${pu}" "${rt}" "skip" "-" "-" "-" "$2" >> "${TABLE}"
}

# Units the board does not have: one skip case each, with the reason
echo "${ABSENT}" | tr ';' '\n' > "${WORK}/absent.txt"
while IFS= read -r a; do
    [ -n "${a}" ] || continue
    info_msg "${a%%=*}: not on this board, ${a#*=}"
    report_skip "${a%%=*}-available"
    printf "%-6s %-10s %-8s %10s %10s %10s  %s\n" "${a%%=*}" "-" "skip" "-" "-" "-" "${a#*=}" >> "${TABLE}"
done < "${WORK}/absent.txt"

# Float32 values of a raw file, one per line.
floats() {
    od -An -v -t f4 "$1" | tr -s ' ' '\n' | sed '/^$/d'
}

# argmax <raw file>: index of the largest value
argmax() {
    floats "$1" | awk 'NR == 1 || $1 > m { m = $1; i = NR - 1 } END { print i }'
}

# cosine <raw a> <raw b>: cosine similarity of two logit vectors. BusyBox
# awk may be built without math functions, so the square root is Newton's.
cosine() {
    floats "$1" > "${WORK}/a.txt"
    floats "$2" > "${WORK}/b.txt"
    paste "${WORK}/a.txt" "${WORK}/b.txt" | awk '
        function root(x,  s, i) {
            if (x <= 0) return 0
            s = (x > 1) ? x : 1
            for (i = 0; i < 200; i++) s = (s + x / s) / 2
            return s
        }
        { ab += $1 * $2; aa += $1 * $1; bb += $2 * $2; n++ }
        END { if (n == 0 || aa == 0 || bb == 0) print 0; else printf "%.6f\n", ab / (root(aa) * root(bb)) }'
}

# maxdiff <raw a> <raw b>: largest absolute difference
maxdiff() {
    floats "$1" > "${WORK}/a.txt"
    floats "$2" > "${WORK}/b.txt"
    paste "${WORK}/a.txt" "${WORK}/b.txt" | awk '
        { d = $1 - $2; if (d < 0) d = -d; if (d > m) m = d; n++ }
        END { if (n == 0) print 1e30; else printf "%.6f\n", m }'
}

# result <run dir> <index>: the output raw of inference <index>
result() {
    find "$1/Result_$2" -name "*.raw" 2>/dev/null | head -n 1
}

# stats <file of ms values>: "mean p50 p90" (nearest rank), or nothing
stats() {
    sort -n "$1" | awk '{ v[NR] = $1; s += $1 }
        END { if (NR == 0) exit
              p50 = int((NR * 50 + 99) / 100); p90 = int((NR * 90 + 99) / 100)
              printf "%.3f %.3f %.3f\n", s / NR, v[p50], v[p90] }'
}

# qnn_latency <run dir>: per-inference times in ms of a qnn-net-run basic
# profile (the EXECUTE events qnn-net-run measures), warm-up dropped
qnn_latency() {
    "${QBIN}/qnn-profile-viewer" --input_log "$1/qnn-profiling-data_0.log" \
        --output "$1/profile.csv" > "$1/profile.txt" 2>&1 || return 1
    awk -F, -v w="${WARMUP}" '$2 == "EXECUTE" && $5 == "NETRUN" {
            n++; if (n > w) printf "%.3f\n", $3 / 1000 }' "$1/profile.csv" > "$1/ms.txt"
    stats "$1/ms.txt"
}

# qnn_run <out dir> <backend lib> <dlc> <input list> [config]: one qnn-net-run
qnn_run() {
    out=$1; backend=$2; dlc=$3; list=$4; cfg=$5
    rm -rf "${out}"
    set -- --backend "${QLIB}/${backend}" --model "${QLIB}/libQnnModelDlc.so" \
        --dlc_path "${dlc}" --input_list "${list}" --output_dir "${out}" \
        --profiling_level basic
    [ -n "${cfg}" ] && set -- "$@" --config_file "${cfg}"
    info_msg "qnn-net-run $*"
    # shellcheck disable=SC2086
    ${TIMEOUT_CMD} "${QBIN}/qnn-net-run" "$@" > "${out}.log" 2>&1
    rc=$?
    tail -n 20 "${out}.log"
    return "${rc}"
}

# tflite_latency <run dir>: per-inference times in ms of a tflite-run (its
# times.txt, microseconds per Invoke()), warm-up dropped
tflite_latency() {
    awk -v w="${WARMUP}" 'NR > w { printf "%.3f\n", $1 / 1000 }' "$1/times.txt" > "$1/ms.txt"
    stats "$1/ms.txt"
}

# tflite_run <out dir> <input list> <tflite-run options>...: one tflite-run,
# in the environment TENV
tflite_run() {
    out=$1; list=$2
    shift 2
    rm -rf "${out}"
    mkdir -p "${out}"
    info_msg "${TENV:+${TENV} }${TFLITE_RUN} --model ${MODEL_DIR}/${TFLITE} $*"
    # shellcheck disable=SC2086
    ${TIMEOUT_CMD} env ${TENV} "${TFLITE_RUN}" --model "${MODEL_DIR}/${TFLITE}" --input_list "${list}" \
        --output_dir "${out}" "$@" > "${out}.log" 2>&1
    rc=$?
    tail -n 20 "${out}.log"
    return "${rc}"
}

# check_top1 <run dir> <tag>: every image's top-1 is its expected class
check_top1() {
    good=0; k=0
    for name in ${names}; do
        exp=$(sed -n "$((k + 1))p" "${WORK}/expected.txt")
        f=$(result "$1" "${k}")
        got=$([ -n "${f}" ] && argmax "${f}")
        info_msg "$2 ${name}: top-1 ${got:-none} ($(sed -n "$((${got:-0} + 1))p" "${MODEL_DIR}/labels.txt")), expected ${exp}"
        [ "${got}" = "${exp}" ] && good=$((good + 1))
        k=$((k + 1))
    done
    info_msg "$2: ${good} of ${n} images classified as expected"
    TOP1="${good}/${n}"
    [ "${good}" -eq "${n}" ]
}

# latency_cases <prefix> <mean p50 p90>: the three latency measurements
latency_cases() {
    if [ -n "$2" ]; then
        # shellcheck disable=SC2086
        set -- "$1" $2
        add_metric "$1-latency" pass "$2" ms
        add_metric "$1-latency-p50" pass "$3" ms
        add_metric "$1-latency-p90" pass "$4" ms
    else
        report_fail "$1-latency"
        report_fail "$1-latency-p50"
        report_fail "$1-latency-p90"
    fi
}

# table <pu> <runtime> <top-1> <"mean p50 p90"> <note>: a comparison row
table() {
    l=${4:-- - -}
    # shellcheck disable=SC2086
    set -- "$1" "$2" "$3" "$5" ${l}
    printf "%-6s %-10s %-8s %10s %10s %10s  %s\n" "$1" "$2" "$3" "$5" "$6" "$7" "$4" >> "${TABLE}"
}

# model_env <key>: a value of the bundle's model.env
model_env() {
    sed -n "s/^$1=//p" "${MODEL_DIR}/model.env" | head -n 1
}

# Inputs: the model, the expected classes and the input lists
names=""; n=0; have_model=0
if [ -n "${MODEL_DIR}" ] && [ -f "${MODEL_DIR}/MANIFEST.sha256" ]; then
    have_model=1
    if (cd "${MODEL_DIR}" && sha256sum -c MANIFEST.sha256 > /dev/null); then
        report_pass inference-model
    else
        (cd "${MODEL_DIR}" && sha256sum -c MANIFEST.sha256 | grep -v ': OK$')
        report_fail inference-model
    fi
    # The bundle is the job's input: read its model.env, do not run it.
    MODEL_NAME=$(model_env MODEL_NAME)
    CPU_DLC=$(model_env CPU_DLC)
    HTP_DLC=$(model_env HTP_DLC)
    TFLITE=$(model_env TFLITE)
    TFLITE_INPUTS=$(model_env TFLITE_INPUTS)
    names=$(cut -d' ' -f1 "${MODEL_DIR}/expected.txt")
    for i in ${names}; do
        echo "${MODEL_DIR}/inputs/${i}.raw"
        n=$((n + 1))
    done > "${WORK}/list.txt"
    if [ "${n}" -eq 0 ]; then
        info_msg "no images in ${MODEL_DIR}/expected.txt"
        report_fail inference-model-images
        have_model=0
    fi
    # timed list: warm-up plus at least RUNS inferences, whole input sets
    t=0
    while [ "${n}" -gt 0 ] && [ "${t}" -lt "$((WARMUP + RUNS))" ]; do
        cat "${WORK}/list.txt"
        t=$((t + n))
    done > "${WORK}/timed-list.txt"
    if [ -n "${TFLITE:-}" ]; then
        for i in ${names}; do
            echo "${MODEL_DIR}/${TFLITE_INPUTS}/${i}.raw"
        done > "${WORK}/tlist.txt"
        t=0
        while [ "${n}" -gt 0 ] && [ "${t}" -lt "$((WARMUP + RUNS))" ]; do
            cat "${WORK}/tlist.txt"
            t=$((t + n))
        done > "${WORK}/ttimed-list.txt"
    fi
    cut -d' ' -f2 "${MODEL_DIR}/expected.txt" > "${WORK}/expected.txt"
    if [ "${NEGATIVE}" = wrong-class ]; then
        { tail -n +2 "${WORK}/expected.txt"; head -n 1 "${WORK}/expected.txt"; } \
            > "${WORK}/expected.rot" && mv "${WORK}/expected.rot" "${WORK}/expected.txt"
    fi
    info_msg "model ${MODEL_NAME}, ${n} images, ${WARMUP} warm-up and ${RUNS}+ timed inferences per unit"
else
    warn_msg "no model bundle${MODEL_DIR:+ in ${MODEL_DIR}}"
    report_skip inference-model
fi

# QAIRT runtime: the zip as published, then only the files the QNN entries run
have_qnn=0
qnn_entries=$(for e in ${PUS}; do r=${e#*:}; case "${r%%:*}" in qnn|qnn-htp|qnn-dsp) echo "$e" ;; esac; done)
if [ -n "${qnn_entries}" ]; then
    if [ -z "${QAIRT_ZIP}" ] || [ ! -f "${QAIRT_ZIP}" ]; then
        warn_msg "no QAIRT SDK zip (${QAIRT_ZIP:-unset})"
        report_skip inference-qairt
    else
        ok=1
        if [ -n "${QAIRT_SHA256}" ]; then
            sum=$(sha256sum "${QAIRT_ZIP}" | cut -d' ' -f1)
            info_msg "QAIRT zip sha256 ${sum}"
            [ "${sum}" = "${QAIRT_SHA256}" ] || { warn_msg "expected ${QAIRT_SHA256}"; ok=0; }
        fi
        QBIN="${WORK}/${QAIRT_ROOT}/bin/${QNN_TARGET}"
        QLIB="${WORK}/${QAIRT_ROOT}/lib/${QNN_TARGET}"
        members="${QAIRT_ROOT}/bin/${QNN_TARGET}/qnn-net-run
${QAIRT_ROOT}/bin/${QNN_TARGET}/qnn-profile-viewer
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnCpu.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnModelDlc.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnSystem.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnIr.so"
        dsp=""
        for e in ${qnn_entries}; do
            r=${e#*:}
            arch=$(echo "$e" | cut -d: -f3)
            au=$(echo "${arch}" | tr v V)
            if [ "${r%%:*}" = qnn-dsp ]; then
                members="${members}
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnDsp.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnDspNetRunExtensions.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnDsp${au}Stub.so
${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned/libQnnDsp${au}Skel.so
${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned/libQnnDsp${au}.so
${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned/libQnnSystem.so"
                dsp="${dsp:+${dsp};}${WORK}/${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned"
                continue
            fi
            [ "${r%%:*}" = qnn-htp ] || continue
            members="${members}
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnHtp.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnHtpPrepare.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnHtpNetRunExtensions.so
${QAIRT_ROOT}/lib/${QNN_TARGET}/libQnnHtp${au}Stub.so
${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned/libQnnHtp${au}Skel.so
${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned/libQnnHtp${au}.so
${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned/libQnnSystem.so"
            dsp="${dsp:+${dsp};}${WORK}/${QAIRT_ROOT}/lib/hexagon-${arch}/unsigned"
        done
        if [ "${ok}" -eq 1 ]; then
            # shellcheck disable=SC2046
            unzip -o -q "${QAIRT_ZIP}" -d "${WORK}" $(echo "${members}" | sort -u) || ok=0
            [ -x "${QBIN}/qnn-net-run" ] || ok=0
        fi
        if [ "${ok}" -eq 1 ]; then
            have_qnn=1
            report_pass inference-qairt
        else
            report_fail inference-qairt
        fi
        export LD_LIBRARY_PATH="${QLIB}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        # FastRPC looks the HTP and DSP skels up in DSP_LIBRARY_PATH.
        if [ -n "${dsp}" ]; then
            export DSP_LIBRARY_PATH="${dsp}${DSP_LIBRARY_PATH:+;${DSP_LIBRARY_PATH}}"
            export ADSP_LIBRARY_PATH="${DSP_LIBRARY_PATH}"
        fi
    fi
fi

cpu_qnn_ok=0
cpu_qnn_mean=""
cpu_tflite_dir=""
for e in ${PUS}; do
    pu=${e%%:*}; rest=${e#*:}; rt=${rest%%:*}
    if [ "${have_model}" -eq 0 ]; then
        skip_entry "$e" "no model bundle${MODEL_DIR:+ in ${MODEL_DIR}}"
        continue
    fi
    case "${rt}" in
    qnn)
        if [ "${have_qnn}" -eq 0 ]; then
            skip_entry "$e" "no QAIRT runtime"
            continue
        fi
        t=${pu}-qnn
        TOP1="-"
        if qnn_run "${WORK}/${t}" libQnnCpu.so "${MODEL_DIR}/${CPU_DLC}" "${WORK}/list.txt" &&
           [ -n "$(result "${WORK}/${t}" $((n - 1)))" ]; then
            cpu_qnn_ok=1
            report_pass "${t}-run"
        else
            report_fail "${t}-run"
        fi
        if [ "${cpu_qnn_ok}" -eq 1 ] && check_top1 "${WORK}/${t}" "${t}"; then
            report_pass "${t}-top1"
        else
            report_fail "${t}-top1"
        fi
        lat=""
        [ "${cpu_qnn_ok}" -eq 1 ] &&
            qnn_run "${WORK}/${t}-timed" libQnnCpu.so "${MODEL_DIR}/${CPU_DLC}" "${WORK}/timed-list.txt" &&
            lat=$(qnn_latency "${WORK}/${t}-timed")
        latency_cases "${t}" "${lat}"
        cpu_qnn_mean=${lat%% *}
        table "${pu}" qnn "${TOP1}" "${lat}" "QNN CPU backend, fp32"
        ;;
    qnn-htp|qnn-dsp)
        if [ "${have_qnn}" -eq 0 ]; then
            skip_entry "$e" "no QAIRT runtime"
            continue
        fi
        dev=$(echo "$e" | cut -d: -f4)
        rp=$(echo "$e" | cut -d: -f5)
        t=${pu}-${rt}
        TOP1="-"
        rpath=$(remoteproc_dirs "${rp}" | head -n 1)
        stopped=0
        if [ "${NEGATIVE}" = htp-down ] && [ -n "${rpath}" ] &&
           [ "$(cat "${rpath}/state")" = running ]; then
            info_msg "negative control: stopping ${rp}"
            echo stop > "${rpath}/state" && stopped=1
            sleep 2
        fi
        state=$([ -n "${rpath}" ] && cat "${rpath}/state")
        info_msg "${t}: QNN $(echo "${rt#qnn-}" | tr '[:lower:]' '[:upper:]') device ${dev}, remoteproc ${rp} ${state:-not registered}"
        ls -l /dev/fastrpc-"${rp}"* 2>&1
        if { [ "${state}" = running ] || [ "${state}" = attached ]; } &&
           ls /dev/fastrpc-"${rp}" /dev/fastrpc-"${rp}"-secure > /dev/null 2>&1; then
            report_pass "${t}-ready"
        else
            report_fail "${t}-ready"
        fi
        if [ "${rt}" = qnn-htp ]; then
            be=libQnnHtp.so
            cat > "${WORK}/${t}-be.json" <<EOF
{
  "devices": [
    {
      "device_id": ${dev},
      "pd_session": "unsigned",
      "cores": [ { "perf_profile": "burst" } ]
    }
  ]
}
EOF
            cat > "${WORK}/${t}-config.json" <<EOF
{
  "backend_extensions": {
    "shared_library_path": "${QLIB}/libQnnHtpNetRunExtensions.so",
    "config_file_path": "${WORK}/${t}-be.json"
  }
}
EOF
            cfg="${WORK}/${t}-config.json"
        else
            # the DSP backend's defaults: unsigned PD, its only device
            be=libQnnDsp.so
            cfg=""
        fi
        ok=0
        if qnn_run "${WORK}/${t}" "${be}" "${MODEL_DIR}/${HTP_DLC}" "${WORK}/list.txt" "${cfg}" &&
           [ -n "$(result "${WORK}/${t}" $((n - 1)))" ]; then
            ok=1
            report_pass "${t}-run"
        else
            report_fail "${t}-run"
        fi
        if [ "${ok}" -eq 1 ] && check_top1 "${WORK}/${t}" "${t}"; then
            report_pass "${t}-top1"
        else
            report_fail "${t}-top1"
        fi
        # against the QNN CPU backend and, for the HTP, the x86 HTP
        # simulation of this Hexagon architecture (host-htp: a bundle with one
        # reference only)
        arch=$(echo "$e" | cut -d: -f3)
        href="${MODEL_DIR}/host-htp-${arch}"
        [ -d "${href}" ] || href="${MODEL_DIR}/host-htp"
        agree=0; close=0; mincos=""; maxd=""; k=0
        for name in ${names}; do
            h=$(result "${WORK}/${t}" "${k}")
            c=$(result "${WORK}/cpu-qnn" "${k}")
            if [ "${ok}" -eq 1 ] && [ "${cpu_qnn_ok}" -eq 1 ] && [ -n "${h}" ] && [ -n "${c}" ]; then
                cs=$(cosine "${h}" "${c}")
                same=$([ "$(argmax "${h}")" = "$(argmax "${c}")" ] && echo yes || echo no)
                info_msg "${t} ${name}: same top-1 as the CPU ${same}, cosine ${cs}"
                if [ "${same}" = yes ] && awk -v c="${cs}" -v m="${MIN_COSINE}" 'BEGIN { exit !(c >= m) }'; then
                    agree=$((agree + 1))
                fi
                mincos=$(awk -v a="${mincos:-${cs}}" -v b="${cs}" 'BEGIN { print (b < a) ? b : a }')
            fi
            if [ "${rt}" = qnn-htp ] && [ "${ok}" -eq 1 ] && [ -n "${h}" ]; then
                md=$(maxdiff "${h}" "${href}/${name}.raw")
                info_msg "${t} ${name}: largest difference to the x86 HTP simulation (${href##*/}) ${md}"
                awk -v a="${md}" -v m="${MAX_HOST_DIFF}" 'BEGIN { exit !(a <= m) }' && close=$((close + 1))
                maxd=$(awk -v a="${maxd:-${md}}" -v b="${md}" 'BEGIN { print (b > a) ? b : a }')
            fi
            k=$((k + 1))
        done
        # no measurement when nothing was compared
        if [ -z "${mincos}" ]; then
            report_fail "${t}-vs-cpu"
        elif [ "${agree}" -eq "${n}" ]; then
            add_metric "${t}-vs-cpu" pass "${mincos}" cosine
        else
            add_metric "${t}-vs-cpu" fail "${mincos}" cosine
        fi
        if [ "${rt}" = qnn-htp ]; then
            if [ -z "${maxd}" ]; then
                report_fail "${t}-vs-host"
            elif [ "${close}" -eq "${n}" ]; then
                add_metric "${t}-vs-host" pass "${maxd}" max-abs-diff
            else
                add_metric "${t}-vs-host" fail "${maxd}" max-abs-diff
            fi
        fi
        lat=""
        [ "${ok}" -eq 1 ] &&
            qnn_run "${WORK}/${t}-timed" "${be}" "${MODEL_DIR}/${HTP_DLC}" \
                    "${WORK}/timed-list.txt" "${cfg}" &&
            lat=$(qnn_latency "${WORK}/${t}-timed")
        latency_cases "${t}" "${lat}"
        # sanity: the NPU must beat the CPU backend of the same runtime
        if [ -n "${lat}" ] && [ -n "${cpu_qnn_mean}" ]; then
            x=$(awk -v c="${cpu_qnn_mean}" -v h="${lat%% *}" 'BEGIN { printf "%.2f\n", (h > 0) ? c / h : 0 }')
            if awk -v x="${x}" 'BEGIN { exit !(x > 1) }'; then
                add_metric "${t}-speedup" pass "${x}" x
            else
                add_metric "${t}-speedup" fail "${x}" x
            fi
        else
            report_fail "${t}-speedup"
        fi
        if [ "${rt}" = qnn-htp ]; then
            table "${pu}" qnn-htp "${TOP1}" "${lat}" "QNN HTP ${dev} (${rp}), 8-bit"
        else
            table "${pu}" qnn-dsp "${TOP1}" "${lat}" "QNN DSP ${arch} (${rp}), 8-bit"
        fi
        if [ "${stopped}" -eq 1 ]; then
            info_msg "negative control: starting ${rp} again"
            echo start > "${rpath}/state"
        fi
        ;;
    tflite|tflite-gpu)
        if [ -z "${TFLITE_RUN}" ]; then
            skip_entry "$e" "no tflite-run, and it cannot be built here"
            continue
        fi
        if [ -z "${TFLITE:-}" ] || [ ! -f "${MODEL_DIR}/${TFLITE}" ]; then
            skip_entry "$e" "no TensorFlow Lite model in ${MODEL_DIR}"
            continue
        fi
        opt=$(echo "$e" | cut -s -d: -f3)
        t=${pu}-${rt}
        TOP1="-"
        TENV=""
        if [ "${rt}" = tflite ]; then
            set -- --delegate xnnpack --threads "${opt:-4}"
            note="TFLite XNNPACK, ${opt:-4} threads, fp32"
        else
            set -- --delegate gpu
            [ "${opt:-fp16}" = fp16 ] && set -- "$@" --gpu_fp16
            note="TFLite GPU delegate (OpenCL), ${opt:-fp16}"
            if [ "${NEGATIVE}" = gpu-down ]; then
                info_msg "negative control: no OpenCL platform for ${t}"
                mkdir -p "${WORK}/no-icd"
                TENV="OCL_ICD_VENDORS=${WORK}/no-icd"
            fi
            # the OpenCL device the delegate will take
            if command -v clinfo > /dev/null; then
                # shellcheck disable=SC2086
                env ${TENV} clinfo -l > "${WORK}/${t}-clinfo.txt" 2>&1
                cat "${WORK}/${t}-clinfo.txt"
                if grep -q "Device" "${WORK}/${t}-clinfo.txt"; then
                    report_pass "${t}-ready"
                else
                    report_fail "${t}-ready"
                fi
            else
                warn_msg "no clinfo: cannot list the OpenCL devices"
                report_skip "${t}-ready"
            fi
        fi
        ok=0
        if tflite_run "${WORK}/${t}" "${WORK}/tlist.txt" "$@" &&
           [ -n "$(result "${WORK}/${t}" $((n - 1)))" ]; then
            ok=1
            report_pass "${t}-run"
        else
            report_fail "${t}-run"
        fi
        if [ "${ok}" -eq 1 ] && check_top1 "${WORK}/${t}" "${t}"; then
            report_pass "${t}-top1"
        else
            report_fail "${t}-top1"
        fi
        if [ "${rt}" = tflite ]; then
            # against the x86 LiteRT run of the same model
            close=0; maxd=""; k=0
            for name in ${names}; do
                h=$(result "${WORK}/${t}" "${k}")
                if [ "${ok}" -eq 1 ] && [ -n "${h}" ]; then
                    md=$(maxdiff "${h}" "${MODEL_DIR}/host-tflite/${name}.raw")
                    info_msg "${t} ${name}: largest difference to the x86 LiteRT run ${md}"
                    awk -v a="${md}" -v m="${MAX_TFLITE_DIFF}" 'BEGIN { exit !(a <= m) }' &&
                        close=$((close + 1))
                    maxd=$(awk -v a="${maxd:-${md}}" -v b="${md}" 'BEGIN { print (b > a) ? b : a }')
                fi
                k=$((k + 1))
            done
            if [ -z "${maxd}" ]; then
                report_fail "${t}-vs-host"
            elif [ "${close}" -eq "${n}" ]; then
                add_metric "${t}-vs-host" pass "${maxd}" max-abs-diff
            else
                add_metric "${t}-vs-host" fail "${maxd}" max-abs-diff
            fi
            [ "${ok}" -eq 1 ] && cpu_tflite_dir="${WORK}/${t}"
        else
            # against TensorFlow Lite on the CPU
            agree=0; mincos=""; k=0
            for name in ${names}; do
                h=$(result "${WORK}/${t}" "${k}")
                c=$([ -n "${cpu_tflite_dir}" ] && result "${cpu_tflite_dir}" "${k}")
                if [ "${ok}" -eq 1 ] && [ -n "${h}" ] && [ -n "${c}" ]; then
                    cs=$(cosine "${h}" "${c}")
                    same=$([ "$(argmax "${h}")" = "$(argmax "${c}")" ] && echo yes || echo no)
                    info_msg "${t} ${name}: same top-1 as the CPU ${same}, cosine ${cs}"
                    if [ "${same}" = yes ] && awk -v c="${cs}" -v m="${MIN_COSINE}" 'BEGIN { exit !(c >= m) }'; then
                        agree=$((agree + 1))
                    fi
                    mincos=$(awk -v a="${mincos:-${cs}}" -v b="${cs}" 'BEGIN { print (b < a) ? b : a }')
                fi
                k=$((k + 1))
            done
            if [ -z "${mincos}" ]; then
                report_fail "${t}-vs-cpu"
            elif [ "${agree}" -eq "${n}" ]; then
                add_metric "${t}-vs-cpu" pass "${mincos}" cosine
            else
                add_metric "${t}-vs-cpu" fail "${mincos}" cosine
            fi
        fi
        lat=""
        [ "${ok}" -eq 1 ] &&
            tflite_run "${WORK}/${t}-timed" "${WORK}/ttimed-list.txt" "$@" &&
            lat=$(tflite_latency "${WORK}/${t}-timed")
        latency_cases "${t}" "${lat}"
        table "${pu}" "${rt}" "${TOP1}" "${lat}" "${note}"
        ;;
    *)
        skip_entry "$e" "unknown runtime ${rt}"
        ;;
    esac
done

echo "=== inference: ${MODEL_NAME:-no model}, latency in ms over ${RUNS}+ timed runs"
printf "%-6s %-10s %-8s %10s %10s %10s  %s\n" PU runtime top-1 mean p50 p90 note
cat "${TABLE}"
exit 0
