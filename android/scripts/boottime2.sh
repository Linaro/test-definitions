#!/system/bin/sh

##############################################################################
## Description about this boot time measuring script                      ####
##############################################################################
## This script will be run on the device, it has following 2 functions:
## 1. collecting the dmesg log and logcat information, and save them under
##        /data/local/tmp/boottime
##    directory in the name for following format:
##       logcat_all_${COLLECT_NO}.log :
##              collected via command "logcat -d -v time *:V"
##       logcat_events_${COLLECT_NO}.log:
##              collected via command "logcat -d -b events -v time"
##       dmesg_${COLLECT_NO}.log:
##              collected via command "dmesg"
##    when this script is run as following:
##       ./android/scripts/boottime2.sh COLLECT ${COLLECT_NO}
##
## 2. analyzing boottime inforamtion from the collected log information
##    when this script is run as following:
##       ./android/scripts/boottime2.sh ANALYZE ${COLLECT_NO}
##
##    it will get the average of multiple iterations for the boot time,
##    so that to get more stable and accurate boot time information:
##
##        iterations < 4:  the average will be calculated with all data
##        iterations >= 4: the average will be calculated with maximum
##                         and minimum will be removed
##    For each iteration, it will get following boot time information:
##    (assuming kernel started at 0 timestamp in this script)
##
##        TOTAL_BOOT_TIME:
##            the sum of KERNEL_BOOT_TIME and ANDROID_BOOT_TIME
##
##        KERNEL_BOOT_TIME:
##            from kernel started to line "Freeing unused kernel memory" printed,
##            it does not include kernel loading and uncompression part done
##            by bootloader or kernel itself
##
##        ANDROID_BOOT_TIME:
##            the sum of INIT_TO_SURFACEFLINGER_START_TIME and SURFACEFLINGER_BOOT_TIME
##
##        SURFACEFLINGER_BOOT_TIME: the time information is gotten from the line
##            contains "Boot is finished" like following in logcat:
##              1-01 00:00:27.158 I/SurfaceFlinger( 1835): Boot is finished (13795 ms)
##            the time here means the time from surfaceflinger service started
##            to the time boot animation finished.
##            it does not include the time from init start to the time
##            surfaceflinger service started
##
##        Also following time values are gotten from dmesg log information,
##        they are not accurate as what we expects, but are able to be used for
##        reference and used for checking our boot time improvements
##
##        INIT_TO_SURFACEFLINGER_START_TIME:
##            from the time "Freeing unused kernel memory" printed in dmesg
##            to the time "init: Starting service 'surfaceflinger'..." is printed
##
##        FS_MOUNT_TIME:
##            from the time "Freeing unused kernel memory:" printed
##            to the time "init: Starting service 'logd'..." printed.
##
##        FS_MOUNT_DURATION:
##            from the line "init: /dev/hw_random not found" printed
##            to the time "init: Starting service 'logd'..." printed
##
##        BOOTANIM_TIME:
##            from the time "init: Starting service 'bootanim'..." printed
##            to the time "init: Service 'bootanim'.* exited with status" printed
##
##        ANDROID_SERVICE_START_TIME:
##            from the time kernel started to the time healthd service started
##
##        ANDROID_UI_SHOWN:
##            time from freeing unused kernel memory to the time
##            when UI is shown on display
##############################################################################

local_file_path="$0"
local_file_parent=$(dirname "${local_file_path}")
local_file_parent=$(cd "${local_file_parent}"||exit; pwd)
# shellcheck source=android/scripts/common.sh
. "${local_file_parent}/common.sh"

local_tmp="/data/local/tmp/"
dir_boottime_data="${local_tmp}/boottime"
F_RAW_DATA_CSV="${dir_boottime_data}/boot_time_raw_data.csv"
F_STATISTIC_DATA_CSV="${dir_boottime_data}/boot_time_statistic_data.csv"


# dmeg line example
# [    7.410422] init: Starting service 'logd'...
getTime(){
    key=$1
    if [ -z "${key}" ]; then
        return
    fi

    key_line=$(grep -i "${key}" "${LOG_DMESG}")
    if [ -n "${key_line}" ]; then
        timestamp=$(echo "${key_line}"|awk '{print $2}' | awk -F "]" '{print $1}')
        echo "${timestamp}"
    fi
}


# logcat_all line example
# 01-01 00:00:26.313 I/SurfaceFlinger( 1850): Boot is finished (11570 ms)
getTimeStampFromLogcat(){
    key=$1
    if [ -z "${key}" ]; then
        return
    fi

    key_line=$(grep -i "${key}" "${LOG_LOGCAT_ALL}")
    if [ -n "${key_line}" ]; then
        timestamp_sec=$(echo "${key_line}"|awk '{print $2}' | awk -F ":" '{print $3}')
        timestamp_min=$(echo "${key_line}"|awk '{print $2}' | awk -F ":" '{print $2}')
        timestamp=$(echo "${timestamp_sec} ${timestamp_min}" | awk '{printf "%.3f",$1 + $2 * 60;}')
        echo "${timestamp}"
    fi
}


getBootTimeInfoFromDmesg(){
    COLLECT_NO=$1

    LOG_LOGCAT_ALL="${dir_boottime_data}/logcat_all_${COLLECT_NO}.log"
    LOG_DMESG="${dir_boottime_data}/dmesg_${COLLECT_NO}.log"

    # dmesg starts before all timers are initialized, so kernel reports time as 0.0.
    # we can't work around this without external time metering.
    # here we presume kernel message starts from 0
    CONSOLE_SECONDS_START=0
    CONSOLE_SECONDS_END=$(getTime "Freeing unused kernel memory")
    if [ ! -z "${CONSOLE_SECONDS_END}" ] && [ ! -z "${CONSOLE_SECONDS_START}" ]; then
        KERNEL_BOOT_TIME=$(echo "${CONSOLE_SECONDS_END} ${CONSOLE_SECONDS_START} - p" | dc)
        output_test_result "KERNEL_BOOT_TIME" "pass" "${KERNEL_BOOT_TIME}" "s"
    fi

    POINT_FS_MOUNT_START=$(getTime "Freeing unused kernel memory:"|tail -n1)
    POINT_FS_MOUNT_END=$(getTime "init: Starting service 'logd'...")
    if [ ! -z "${POINT_FS_MOUNT_END}" ] && [ ! -z "${POINT_FS_MOUNT_START}" ]; then
        FS_MOUNT_TIME=$(echo "${POINT_FS_MOUNT_END} ${POINT_FS_MOUNT_START} - p" | dc)
        output_test_result "FS_MOUNT_TIME" "pass" "${FS_MOUNT_TIME}" "s"
    fi

    POINT_FS_DURATION_START=$(getTime "init: /dev/hw_random not found"|tail -n1)
    POINT_FS_DURATION_END=$(getTime "init: Starting service 'logd'...")
    if [ ! -z "${POINT_FS_DURATION_END}" ] && [ ! -z "${POINT_FS_DURATION_START}" ]; then
        FS_MOUNT_DURATION=$(echo "${POINT_FS_DURATION_END} ${POINT_FS_DURATION_START} - p" | dc)
        output_test_result "FS_MOUNT_DURATION" "pass" "${FS_MOUNT_DURATION}" "s"
    fi

    POINT_SERVICE_BOOTANIM_START=$(getTime "init: Starting service 'bootanim'..."|tail -n1)
    POINT_SERVICE_BOOTANIM_END=$(getTime "init: Service 'bootanim'.* exited with status"|tail -n1)
    if [ ! -z "${POINT_SERVICE_BOOTANIM_END}" ] && [ ! -z "${POINT_SERVICE_BOOTANIM_START}" ]; then
        BOOTANIM_TIME=$(echo "${POINT_SERVICE_BOOTANIM_END} ${POINT_SERVICE_BOOTANIM_START} - p" | dc)
        output_test_result "BOOTANIM_TIME" "pass" "${BOOTANIM_TIME}" "s"
    fi

    POINT_INIT_START=$(getTime "Freeing unused kernel memory")
    POINT_SERVICE_SURFACEFLINGER_START=$(getTime "init: Starting service 'surfaceflinger'..."|tail -n1)
    if [ ! -z "${POINT_SERVICE_SURFACEFLINGER_START}" ] && [ ! -z "${POINT_INIT_START}" ]; then
        INIT_TO_SURFACEFLINGER_START_TIME=$(echo "${POINT_SERVICE_SURFACEFLINGER_START} ${POINT_INIT_START} - p" | dc)
        output_test_result "INIT_TO_SURFACEFLINGER_START_TIME" "pass" "${INIT_TO_SURFACEFLINGER_START_TIME}" "s"
    fi

    POINT_SURFACEFLINGER_BOOT=$(getTimeStampFromLogcat "Boot is finished")
    POINT_SURFACEFLINGER_START=$(getTimeStampFromLogcat "SurfaceFlinger is starting")
    POINT_LAUNCHER_DISPLAYED=$(getTimeStampFromLogcat "Displayed com.android.launcher")

    ## When there are 2 lines of "Boot is finished",
    ## it mostly means that the surfaceflinger service restarted by some reason
    ## but here when there are multiple lines of "Boot is finished",
    ## use the last one line, and report the case later after checked all the logs
    SURFACEFLINGER_BOOT_TIME_INFO=$(grep "Boot is finished" "${LOG_LOGCAT_ALL}"|tail -n1)
    if [ -n "${SURFACEFLINGER_BOOT_TIME_INFO}" ]; then
        while echo "${SURFACEFLINGER_BOOT_TIME_INFO}"|grep -q "("; do
            SURFACEFLINGER_BOOT_TIME_INFO=$(echo "${SURFACEFLINGER_BOOT_TIME_INFO}"|cut -d\( -f2-)
        done
        SURFACEFLINGER_BOOT_TIME_MS=$(echo "${SURFACEFLINGER_BOOT_TIME_INFO}"|cut -d\  -f1)
        SURFACEFLINGER_BOOT_TIME=$(echo "${SURFACEFLINGER_BOOT_TIME_MS}" | awk '{printf "%.3f",$1/1000;}')
        output_test_result "SURFACEFLINGER_BOOT_TIME" "pass" "${SURFACEFLINGER_BOOT_TIME}" "s"

        if [ ! -z "${POINT_SURFACEFLINGER_BOOT}" ] && [ ! -z "${POINT_LAUNCHER_DISPLAYED}" ] && [ ! -z "${POINT_SURFACEFLINGER_START}" ] && [ ! -z "${INIT_TO_SURFACEFLINGER_START_TIME}" ]; then

                min=$(echo "${POINT_LAUNCHER_DISPLAYED} ${POINT_SURFACEFLINGER_BOOT}" | awk '{if ($1 < $2) printf $1; else print $2}')

                ## In case timestamp of "Boot is finished" is smaller than timestamp of "Displayed com.android.launcher" we calculate ANDROID_UI_SHOWN as "Boot is finished" time minus difference
                ## between two timestamps plus INIT_TO_SURFACEFLINGER_START_TIME
                if [ "${min}" = "${POINT_SURFACEFLINGER_BOOT}" ]; then
                        ANDROID_UI_SHOWN=$(echo "${POINT_SURFACEFLINGER_BOOT} ${POINT_SURFACEFLINGER_START} ${POINT_SURFACEFLINGER_BOOT} ${POINT_LAUNCHER_DISPLAYED} ${INIT_TO_SURFACEFLINGER_START_TIME}" | awk '{printf "%.3f",$1 - $2 + $4 - $3 + $5;}')
                ## I case timestamp of "Boot is finished" is greater than timestamp of "Displayed com.android.launcher" we use "Boot is finished" time plus INIT_TO_SURFACEFLINGER_START_TIME
                ## as ANDROID_UI_SHOWN
                else
                        ANDROID_UI_SHOWN=$(echo "${POINT_SURFACEFLINGER_BOOT} ${POINT_SURFACEFLINGER_START} ${INIT_TO_SURFACEFLINGER_START_TIME}" | awk '{printf "%.3f",$1 - $2 + $3;}')
                fi
                output_test_result "ANDROID_UI_SHOWN" "pass" "${ANDROID_UI_SHOWN}" "s"
        fi
    fi


    if [ ! -z "${INIT_TO_SURFACEFLINGER_START_TIME}" ] && [ ! -z "${SURFACEFLINGER_BOOT_TIME}" ] ; then
        ANDROID_BOOT_TIME=$(echo "${INIT_TO_SURFACEFLINGER_START_TIME} ${SURFACEFLINGER_BOOT_TIME}" | awk '{printf "%.3f",$1 + $2;}')
        output_test_result "ANDROID_BOOT_TIME" "pass" "${ANDROID_BOOT_TIME}" "s"
    fi

    SERVICE_START_TIME_INFO=$(grep "healthd:" "${LOG_DMESG}"|head -n 1)
    SERVICE_START_TIME_END=$(echo "${SERVICE_START_TIME_INFO}"|cut -d] -f 1|cut -d[ -f2| tr -d " ")
    if [ ! -z "${SERVICE_START_TIME_END}" ] && [ ! -z "${CONSOLE_SECONDS_START}" ]; then
        SERVICE_START_TIME=$(echo "${SERVICE_START_TIME_END} ${CONSOLE_SECONDS_START} - p" | dc)
        output_test_result "ANDROID_SERVICE_START_TIME" "pass" "${SERVICE_START_TIME}" "s"
    fi

    if [ ! -z "${KERNEL_BOOT_TIME}" ] && [ ! -z "${ANDROID_BOOT_TIME}" ] ; then
        TOTAL_SECONDS=$(echo "${KERNEL_BOOT_TIME} ${ANDROID_BOOT_TIME}" | awk '{printf "%.3f",$1 + $2;}')
        output_test_result "TOTAL_BOOT_TIME" "pass" "${TOTAL_SECONDS}" "s"
    fi
}

OPERATION=$1
if [ "X${OPERATION}" = "XCOLLECT" ]; then
    G_VERBOSE_OUTPUT=FALSE
    G_RECORD_LOCAL_CSV=FALSE
    COLLECT_NO=$2
    mkdir -p ${dir_boottime_data}

    # shellcheck disable=SC2035
    logcat -d -v time *:V > "${dir_boottime_data}/logcat_all_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_LOGCAT_ALL_COLLECT" "pass"
    logcat -d -b events -v time > "${dir_boottime_data}/logcat_events_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_LOGCAT_EVENTS_COLLECT" "pass"
    dmesg > "${dir_boottime_data}/dmesg_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_DMESG_COLLECT" "pass"
elif [ "X${OPERATION}" = "XANALYZE" ]; then
    count=$2
    ## Check if there is any case that the surfaceflinger service
    ## was started several times
    i=1
    service_started_once=true
    no_boot_timeout_force_display=true
    while ${service_started_once}; do
        if [ $i -gt "$count" ]; then
            break
        fi
        ## check the existence of "Boot is finished"
        LOG_LOGCAT_ALL="${dir_boottime_data}/logcat_all_${i}.log"
        android_boottime_lines=$(grep -c "Boot is finished" "${LOG_LOGCAT_ALL}")
        if [ "${android_boottime_lines}" -ne 1 ]; then
            echo "There are ${android_boottime_lines} existences of 'Boot is finished' in file: ${LOG_LOGCAT_ALL}"
            echo "Please check the status first"
            service_started_once=false
        fi

        if grep -q "BOOT TIMEOUT: forcing display enabled" "${LOG_LOGCAT_ALL}"; then
            no_boot_timeout_force_display=false
            echo "There are boot timeout problem in file: ${LOG_LOGCAT_ALL}"
            echo "Please check the status first"
            break
        fi

        LOG_DMESG="${dir_boottime_data}/dmesg_${i}.log"
        ## check  the service of bootanim
        bootanim_lines=$(grep -c "init: Service 'bootanim'.* exited with status" "${LOG_DMESG}")
        if [ "${bootanim_lines}" -ne 1 ]; then
            echo "bootanim service seems to be started more than once in file: ${LOG_DMESG}"
            echo "Please check the status first"
            service_started_once=false
        fi
        i=$((i+1))
    done

    if ! ${no_boot_timeout_force_display}; then
        output_test_result "NO_BOOT_TIMEOUT_FORCE_DISPLAY" "fail"
    fi
    if ! ${service_started_once}; then
        output_test_result "SERVICE_STARTED_ONCE" "fail"
    fi

    if ${no_boot_timeout_force_display} && ${service_started_once}; then
        no_checking_problem=true
    else
        no_checking_problem=false
    fi

    if ${no_checking_problem}; then
        i=1
        G_RESULT_NOT_RECORD=TRUE
        G_RECORD_LOCAL_CSV=TRUE
        export G_RECORD_LOCAL_CSV G_RESULT_NOT_RECORD
        while true; do
            if [ $i -gt "$count" ]; then
                break
            fi
            getBootTimeInfoFromDmesg ${i}
            i=$((i+1))
        done
        G_RESULT_NOT_RECORD=FALSE
        export G_RESULT_NOT_RECORD
        if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
            statistic ${F_RAW_DATA_CSV} 2 |tee ${F_STATISTIC_DATA_CSV}
            sed -i 's/=/,/' "${F_STATISTIC_DATA_CSV}"

            G_RECORD_LOCAL_CSV=FALSE
            export G_RECORD_LOCAL_CSV
            while read -r line; do
                if ! echo "$line"|grep -q ,; then
                    continue
                fi
                key=$(echo "$line"|cut -d, -f1)
                measurement=$(echo "$line"|cut -d, -f2)
                units=$(echo "$line"|cut -d, -f3)
                output_test_result "${key}" "pass" "${measurement}" "${units}"
            done < "${F_STATISTIC_DATA_CSV}"
        fi

        output_test_result "SERVICE_STARTED_ONCE" "pass"
    fi

    # set again for following output_test_result
    G_RECORD_LOCAL_CSV=FALSE
    cd ${local_tmp}|| exit 1
    tar -czvf boottime.tgz boottime
    if [ -n "$(which lava-test-run-attach)" ]; then
        lava-test-run-attach boottime.tgz application/x-gzip
    fi
    output_test_result "BOOTTIME_ANALYZE" "pass"
else
    G_VERBOSE_OUTPUT=FALSE
    G_RECORD_LOCAL_CSV=FALSE
    export G_VERBOSE_OUTPUT G_RECORD_LOCAL_CSV
    echo "Not recognised operation"
    output_test_result "BOOTTIME" "fail"
fi
