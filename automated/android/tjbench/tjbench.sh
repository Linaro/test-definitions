#!/bin/sh -e
# shellcheck disable=SC2039
# shellcheck disable=SC1091

ANDROID_SERIAL=""
BOOT_TIMEOUT="300"
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
IMGS="nightshot_iso_100.ppm"
LOOPS="1"
SKIP_INSTALL="false"

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

usage() {
    echo "Usage: $0 [-s <android_serial>] [-t <boot_timeout>] [-l <loops>] [-S <true|false>]" 1>&2
    exit 1
}

while getopts ":s:t:l:S:" o; do
  case "$o" in
    s) ANDROID_SERIAL="${OPTARG}" ;;
    t) BOOT_TIMEOUT="${OPTARG}" ;;
    l) LOOPS="${OPTARG}" ;;
    S) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

initialize_adb
wait_boot_completed "${BOOT_TIMEOUT}"
create_out_dir "${OUTPUT}"
install_deps "wget" "${SKIP_INSTALL}"

parse_log() {
    local logfile="$1"
    local prefix="$2_subsamp"

    grep "^RGB" "${logfile}" \
        | awk -v prefix="$prefix" \
             '{
                  gsub(":", "", $3);
                  printf("%s_%s_comp_perf pass %s Mpixels/sec\n", prefix, $3, $7);
                  printf("%s_%s_comp_ratio pass %s percent\n", prefix, $3, $8);
                  printf("%s_%s_decomp_perf pass %s Mpixels/sec\n", prefix, $3, $9);
              }' \
        | tee -a "${RESULT_FILE}"
}

if adb_shell_which "tjbench32" || adb_shell_which "tjbench64"; then
    cmd_name="tjbench"
elif adb_shell_which "tj32" || adb_shell_which "tj64"; then
    cmd_name="tj"
else
    report_fail "check_cmd_existence"
    exit 0
fi

for img in ${IMGS}; do
    [ ! -f "./${img}" ] && \
        wget -S --progress=dot:mega "http://testdata.validation.linaro.org/tjbench/${img}"
    adb_push "./${img}" "/data/local/tmp/tjbench/"
    img_path="/data/local/tmp/tjbench/${img}"

    for test in ${cmd_name}32 ${cmd_name}64; do
        if ! adb_shell_which "${test}"; then
            continue
        fi
        img_name="$(echo "${img}" | sed 's/[.]/_/g')"
        case "${test}" in
            ${cmd_name}32) prefix="32bit_${img_name}" ;;
            ${cmd_name}64) prefix="64bit_${img_name}" ;;
        esac

        info_msg "device-${ANDROID_SERIAL}: About to run ${test}..."
        for i in $(seq "${LOOPS}"); do
            info_msg "Running iteration [${i}/${LOOPS}]..."
            adb shell "${test} ${img_path} 95 -rgb -quiet scale 1/2" | tee -a "${OUTPUT}/${test}-w1-h2.log"
            adb shell "${test} ${img_path} 95 -rgb -quiet" | tee -a "${OUTPUT}/${test}.log"
        done
        parse_log "${OUTPUT}/${test}-w1-h2.log" "${prefix}_scale_w1_h2"
        parse_log "${OUTPUT}/${test}.log" "${prefix}"
    done
done

# Calculate min, mean and max.
if [ "${LOOPS}" -gt 2 ]; then
    tc_list=$(awk '{print $1}' "${RESULT_FILE}" | sort -u)
    for tc in ${tc_list}; do
        grep "$tc" "${RESULT_FILE}" \
            | awk -v tc="${tc}" \
                  '{
                       if(min=="") {min=max=$3};
                       if($3>max) {max=$3};
                       if($3< min) {min=$3};
                       total+=$3; count+=1;
                   }
               END {
                       printf("%s-min pass %s %s\n", tc, min, $4);
                       printf("%s-mean pass %s %s\n", tc, total/count, $4);
                       printf("%s-max pass %s %s\n", tc, max, $4)
                   }' \
            | tee -a "${RESULT_FILE}"
    done
fi
