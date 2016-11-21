#!/system/bin/sh

local_file_path="$0"
local_file_parent=$(cd $(dirname ${local_file_path}); pwd)
. ${local_file_parent}/common.sh

local_tmp="/data/local/tmp/"
dir_boottime_data="${local_tmp}/boottime"
F_RAW_DATA_CSV="${dir_boottime_data}/boot_time_raw_data.csv"
F_STATISTIC_DATA_CSV="${dir_boottime_data}/boot_time_statistic_data.csv"


# dmeg line example
# [    7.410422] init: Starting service 'logd'...
getTime(){
    local key=$1
    if [ -z "${key}" ]; then
        return
    fi

    local key_line=$(grep "${key}" ${LOG_DMESG})
    if [ -n "${key_line}" ]; then
        local timestamp=$(echo "${key_line}"|awk '{print $2}' | awk -F "]" '{print $1}')
        echo "${timestamp}"
    fi
}

function getBootTimeInfoFromDmesg(){
    COLLECT_NO=$1

    LOG_LOGCAT_ALL="${dir_boottime_data}/logcat_all_${COLLECT_NO}.log"
    LOG_DMESG="${dir_boottime_data}/dmesg_${COLLECT_NO}.log"

    # dmesg starts before all timers are initialized, so kernel reports time as 0.0.
    # we can't work around this without external time metering.
    # here we presume kernel message starts from 0
    CONSOLE_SECONDS_START=0
    CONSOLE_SECONDS_END=$(getTime "Freeing unused kernel memory")
    CONSOLE_SECONDS=`echo "$CONSOLE_SECONDS_END $CONSOLE_SECONDS_START - p" | dc`
    output_test_result "KERNEL_BOOT_TIME" "pass" "${CONSOLE_SECONDS}" "s"

    POINT_FS_MOUNT_START=$(getTime "Freeing unused kernel memory:"|tail -n1)
    POINT_FS_MOUNT_END=$(getTime "init: Starting service 'logd'...")
    FS_MOUNT_TIME=`echo "${POINT_FS_MOUNT_END} ${POINT_FS_MOUNT_START} - p" | dc`
    output_test_result "FS_MOUNT_TIME" "pass" "${FS_MOUNT_TIME}" "s"

    POINT_FS_DURATION_START=$(getTime "init: /dev/hw_random not found"|tail -n1)
    POINT_FS_DURATION_END=$(getTime "init: Starting service 'logd'...")
    FS_MOUNT_DURATION=`echo "${POINT_FS_DURATION_END} ${POINT_FS_DURATION_START} - p" | dc`
    output_test_result "FS_MOUNT_DURATION" "pass" "${FS_MOUNT_DURATION}" "s"

    POINT_SERVICE_BOOTANIM_START=$(getTime "init: Starting service \'bootanim\'...")
    POINT_SERVICE_BOOTANIM_END=$(getTime "init: Service 'bootanim'.* exited with status")
    BOOTANIM_TIME=`echo "${POINT_SERVICE_BOOTANIM_END} ${POINT_SERVICE_BOOTANIM_START} - p" | dc`
    output_test_result "BOOTANIM_TIME" "pass" "${BOOTANIM_TIME}" "s"

    TIME_INFO=$(grep "Boot is finished" ${LOG_LOGCAT_ALL})
    if [ -z "${TIME_INFO}" ]; then
        output_test_result "ANDROID_BOOT_TIME" "fail" "-1" "s"
    else
        while echo "${TIME_INFO}"|grep -q "("; do
            TIME_INFO=$(echo "${TIME_INFO}"|cut -d\( -f2-)
        done
        TIME_VALUE=$(echo "${TIME_INFO}"|cut -d\  -f1)
        ANDROID_BOOT_TIME=`echo $TIME_VALUE 1000 / p | dc`
        output_test_result "ANDROID_BOOT_TIME" "pass" "${ANDROID_BOOT_TIME}" "s"
    fi

    SERVICE_START_TIME_INFO=$(grep "healthd:" ${LOG_DMESG}|head -n 1)
    SERVICE_START_TIME_END=$(echo "$SERVICE_START_TIME_INFO"|cut -d] -f 1|cut -d[ -f2| tr -d " ")
    if [ -z "${SERVICE_START_TIME_END}" ]; then
        output_test_result "ANDROID_SERVICE_START_TIME" "fail" "-1" "s"
    else
        SERVICE_START_TIME=`echo "$SERVICE_START_TIME_END $CONSOLE_SECONDS_START - p" | dc`
        output_test_result "ANDROID_SERVICE_START_TIME" "pass" "${SERVICE_START_TIME}" "s"
    fi

    echo "$CONSOLE_SECONDS $TIME_VALUE 1000 / + p"
    TOTAL_SECONDS=`echo "$CONSOLE_SECONDS $TIME_VALUE 1000 / + p" | dc`
    output_test_result "TOTAL_BOOT_TIME" "pass" "${TOTAL_SECONDS}" "s"
}

OPERATION=$1
if [ "X${OPERATION}" = "XCOLLECT" ]; then
    G_VERBOSE_OUTPUT=FALSE
    G_RECORD_LOCAL_CSV=FALSE
    COLLECT_NO=$2
    mkdir -p ${dir_boottime_data}

    logcat -d -v time *:V > ${dir_boottime_data}/logcat_all_${COLLECT_NO}.log
    output_test_result "BOOTTIME_LOGCAT_ALL_COLLECT" "pass"
    logcat -d -b events -v time > ${dir_boottime_data}/logcat_events_${COLLECT_NO}.log
    output_test_result "BOOTTIME_LOGCAT_EVENTS_COLLECT" "pass"
    dmesg > ${dir_boottime_data}/dmesg_${COLLECT_NO}.log
    output_test_result "BOOTTIME_DMESG_COLLECT" "pass"
elif [ "X${OPERATION}" = "XANALYZE" ]; then
    count=$2
    i=1
    G_RESULT_NOT_RECORD=TRUE
    G_RECORD_LOCAL_CSV=TRUE
    while true; do
        if [ $i -gt $count ]; then
            break
        fi
        getBootTimeInfoFromDmesg ${i}
        i=$((i+1))
    done
    G_RESULT_NOT_RECORD=FALSE
    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        statistic ${F_RAW_DATA_CSV} 2 |tee ${F_STATISTIC_DATA_CSV}
        sed -i 's/=/,/' "${F_STATISTIC_DATA_CSV}"

        G_RECORD_LOCAL_CSV=FALSE
        for line in $(cat "${F_STATISTIC_DATA_CSV}"); do
            if ! echo "$line"|grep -q ,; then
                continue
            fi
            local key=$(echo $line|cut -d, -f1)
            local measurement=$(echo $line|cut -d, -f2)
            local units=$(echo $line|cut -d, -f3)
            output_test_result "${key}" "pass" "${measurement}" "${units}"
        done
    fi
    # set again for following output_test_result
    G_RECORD_LOCAL_CSV=FALSE
    cd ${local_tmp}
    tar -czvf boottime.tgz boottime
    lava-test-run-attach boottime.tgz application/x-gzip
    output_test_result "BOOTTIME_ANALYZE" "pass"
else
    G_VERBOSE_OUTPUT=FALSE
    G_RECORD_LOCAL_CSV=FALSE
    echo "Not recognised operation" 
    output_test_result "BOOTTIME" "fail"
fi
