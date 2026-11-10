#!/bin/sh
# RTLA provides a set of tools for the analysis of the kernel’s
# realtime behavior on specific hardware.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
TMPFILE="${OUTPUT}/rtla-osnoise.txt"
LOGFILE="${OUTPUT}/rtla-osnoise.json"
RESULT_FILE="${OUTPUT}/result.txt"
RCFILE="${OUTPUT}/rtla-osnoise.rc"

DURATION="1m"
BACKGROUND_CMD=""
HOUSEKEEPING="0"

usage() {
    echo "Usage: $0 [-d duration ] [-w background_cmd] [-H housekeeping_cpus]" 1>&2
    exit 1
}

while getopts ":d:w:H:" opt; do
    case "${opt}" in
        d) DURATION="${OPTARG}" ;;
	w) BACKGROUND_CMD="${OPTARG}" ;;
	H) HOUSEKEEPING="${OPTARG}" ;;
        *) usage ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"

# Print the CPUs of a cpu list such as "0-3,6", one per line.
expand_cpus() {
    echo "$1" | tr ',' '\n' | while IFS=- read -r first last; do
        [ -n "${first}" ] && seq "${first}" "${last:-${first}}"
    done
}

# rtla itself is busy while it collects the samples. It runs as a normal
# task, and the fair server gives it CPU time even next to the osnoise
# threads, so on a measured CPU its own work shows up as thread noise of
# up to milliseconds. Keep rtla on the housekeeping CPUs and measure only
# the others; with a single CPU there is no choice, so measure all.
CPU_OPTS=""
if [ -n "${HOUSEKEEPING}" ]; then
    hk=" $(expand_cpus "${HOUSEKEEPING}" | tr '\n' ' ')"
    monitored=$(expand_cpus "$(cat /sys/devices/system/cpu/online)" \
                | awk -v hk="${hk}" 'index(hk, " " $1 " ") == 0' | paste -sd, -)
    if [ -n "${monitored}" ]; then
        CPU_OPTS="-H ${HOUSEKEEPING} -c ${monitored}"
        info_msg "rtla on CPUs ${HOUSEKEEPING}, measuring CPUs ${monitored}"
    else
        warn_msg "no CPU left besides housekeeping CPUs ${HOUSEKEEPING}, measuring all"
    fi
fi

background_process_start bgcmd --cmd "${BACKGROUND_CMD}"

# real-time priority FIFO:1, for 900ms at each period (1s by default)
# The pipe to tee loses rtla's exit code, keep it in a file.
# shellcheck disable=SC2086
{ rtla osnoise hist -P F:1 -r 900000 -d "${DURATION}" ${CPU_OPTS} --trace \
     --event osnoise:irq_noise \
     --trigger hist:key=cpu,desc,duration.buckets=1000:sort=duration \
     --event osnoise:thread_noise \
     --trigger hist:key=cpu,comm,duration.buckets=1000:sort=duration \
     --event osnoise:sample_threshold \
     --trigger 'hist:key=cpu,duration.buckets=1000:sort=duration if interference == 0'; \
  echo $? > "${RCFILE}"; } | tee -a "${TMPFILE}"

background_process_stop bgcmd

mv osnoise_thread_noise_hist.txt "${OUTPUT}"
mv osnoise_irq_noise_hist.txt "${OUTPUT}"
mv osnoise_sample_threshold_hist.txt "${OUTPUT}"
# Parse test log.
./parse_rtla.py -t osnoise -r "${TMPFILE}" -o "${LOGFILE}" -c "$(cat "${RCFILE}")"
../../lib/parse_rt_tests_results.py rtla-osnoise "${LOGFILE}" \
    | tee -a "${RESULT_FILE}"
