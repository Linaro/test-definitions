#!/bin/sh
# RTLA provides a set of tools for the analysis of the kernel’s
# realtime behavior on specific hardware.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
TMPFILE="${OUTPUT}/rtla-timerlat.txt"
LOGFILE="${OUTPUT}/rtla-timerlat.json"
RESULT_FILE="${OUTPUT}/result.txt"

DURATION="1m"
BACKGROUND_CMD=""

usage() {
    echo "Usage: $0 [-d duration ] [-w background_cmd]" 1>&2
    exit 1
}

while getopts ":d:w:" opt; do
    case "${opt}" in
        d) DURATION="${OPTARG}" ;;
	w) BACKGROUND_CMD="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

rtla timerlat hist --dma-latency=0 -d "${DURATION}" --no-header --trace \
     -e osnoise:irq_noise \
     --trigger hist:key=cpu,desc,duration.buckets=1000:sort=duration \
     -e osnoise:thread_noise \
     --trigger hist:key=cpu,comm,duration.buckets=1000:sort=duration \
    | tee -a "${TMPFILE}"

background_process_stop bgcmd

mv osnoise_thread_noise_hist.txt "${OUTPUT}"
mv osnoise_irq_noise_hist.txt "${OUTPUT}"
# Parse test log.
./parse_rtla.py -t timerlat -r "${TMPFILE}" -o "${LOGFILE}"
../../lib/parse_rt_tests_results.py rtla-timerlat "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
