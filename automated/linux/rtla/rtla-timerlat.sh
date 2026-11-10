#!/bin/sh
# RTLA provides a set of tools for the analysis of the kernel’s
# realtime behavior on specific hardware.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
TMPFILE="${OUTPUT}/rtla-timerlat.txt"
LOGFILE="${OUTPUT}/rtla-timerlat.json"
RESULT_FILE="${OUTPUT}/result.txt"
RCFILE="${OUTPUT}/rtla-timerlat.rc"

DURATION="1m"
BACKGROUND_CMD=""
CPUS=""

usage() {
    echo "Usage: $0 [-d duration ] [-w background_cmd] [-c cpus]" 1>&2
    exit 1
}

while getopts ":d:w:c:" opt; do
    case "${opt}" in
        d) DURATION="${OPTARG}" ;;
	w) BACKGROUND_CMD="${OPTARG}" ;;
	c) CPUS="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# /dev/cpu_dma_latency only exists with CONFIG_CPU_IDLE; without it rtla
# refuses to run if asked to set it, but there are no idle states to
# keep the CPUs out of either.
DMA_LATENCY=""
if [ -e /dev/cpu_dma_latency ]; then
    DMA_LATENCY="--dma-latency=0"
fi

# Measure only these CPUs (e.g. the isolated ones); rtla then keeps its
# own threads on the others.
CPU_OPTS=""
if [ -n "${CPUS}" ]; then
    CPU_OPTS="-c ${CPUS}"
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

# The pipe to tee loses rtla's exit code, keep it in a file.
# shellcheck disable=SC2086
{ rtla timerlat hist ${DMA_LATENCY} -d "${DURATION}" ${CPU_OPTS} --trace \
     --event osnoise:irq_noise \
     --trigger hist:key=cpu,desc,duration.buckets=1000:sort=duration \
     --event osnoise:thread_noise \
     --trigger hist:key=cpu,comm,duration.buckets=1000:sort=duration; \
  echo $? > "${RCFILE}"; } | tee -a "${TMPFILE}"

background_process_stop bgcmd

mv osnoise_thread_noise_hist.txt "${OUTPUT}"
mv osnoise_irq_noise_hist.txt "${OUTPUT}"
# Parse test log.
./parse_rtla.py -t timerlat -r "${TMPFILE}" -o "${LOGFILE}" -c "$(cat "${RCFILE}")"
../../lib/parse_rt_tests_results.py rtla-timerlat "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
