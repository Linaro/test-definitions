#!/bin/sh
# RTLA provides a set of tools for the analysis of the kernel’s
# realtime behavior on specific hardware.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
TMPFILE="${OUTPUT}/rtla-osnoise.txt"
LOGFILE="${OUTPUT}/rtla-osnoise.json"
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

# real-time priority FIFO:1, on all CPUs, for 900ms at each period (1s by default)
rtla osnoise hist -P F:1 -r 900000 -d "${DURATION}" --no-header --trace \
     --event osnoise:irq_noise \
     --trigger hist:key=cpu,desc,duration.buckets=1000:sort=duration \
     --event osnoise:thread_noise \
     --trigger hist:key=cpu,comm,duration.buckets=1000:sort=duration \
     --event osnoise:sample_threshold \
     --trigger 'hist:key=cpu,duration.buckets=1000:sort=duration if interference == 0' \
    | tee -a "${TMPFILE}"

background_process_stop bgcmd

mv osnoise_thread_noise_hist.txt "${OUTPUT}"
mv osnoise_irq_noise_hist.txt "${OUTPUT}"
mv osnoise_sample_threshold_hist.txt "${OUTPUT}"
# Parse test log.
./parse_rtla.py -t osnoise -r "${TMPFILE}" -o "${LOGFILE}"
../../lib/parse_rt_tests_results.py rtla-osnoise "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
