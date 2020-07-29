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
##       prop_${COLLECT_NO}.log:
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

local_tmp="/data/local/tmp/"
dir_boottime_data="${local_tmp}/boottime"
F_RAW_DATA_CSV="${dir_boottime_data}/boot_time_raw_data.csv"
F_STATISTIC_DATA_CSV="${dir_boottime_data}/boot_time_statistic_data.csv"
RESULT_FILE="${dir_boottime_data}/result.txt"

## Copied from android/scripts/common.sh.
G_RECORD_LOCAL_CSV=TRUE
G_VERBOSE_OUTPUT=FALSE
G_RESULT_NOT_RECORD=FALSE

## Description:
##    output the max value of the passed 2 parameters
## Usage:
##    f_max "${val1}" "${val2}"
## Example:
##    max=$(f_max "1.5" "2.0")
f_max(){
    val1=$1
    val2=$2
    [ -z "$val1" ] && echo "$val2"
    [ -z "$val2" ] && echo "$val1"

    echo "$val1,$val2"|awk -F, '{if($1<$2) print $2; else print $1}'
}

## Description:
##    output the min value of the passed 2 parameters
## Usage:
##    f_min "${val1}" "${val2}"
## Example:
##    min=$(f_min "1.5" "2.0")
f_min(){
    val1=$1
    val2=$2
    [ -z "$val1" ] && echo "$val1"
    [ -z "$val2" ] && echo "$val2"

    echo "$val1,$val2"|awk -F, '{if($1>$2) print $2; else print $1}'
}

## Description:
##   calculate the average value for specified csv file.
##   The first field of that csv file should be the key/name of that line,
##   Lines have the same key should be together.
## Usage:
##    statistic "${csv_file_path}" "${file_number}"
## Example:
##    statistic "$f_res_starttime" 2
## Note:
##    if less than 4 samples for that key/item there, average will be calculated as total/count
##    if 4 or more samples for that key/item there, average will be calculated with max and min excluded
statistic(){
    f_data=$1
    if ! [ -f "$f_data" ]; then
        return
    fi
    field_no=$2
    if [ -z "$field_no" ]; then
        field_no=2
    fi
    total=0
    max=0
    min=0
    old_key=""
    new_key=""
    count=0
    units=""
    sort "${f_data}" >"${f_data}.sort"
    while read -r line; do
        line=$(echo "$line"|tr ' ' '~')
        if ! echo "$line"|grep -q ,; then
            continue
        fi
        new_key=$(echo "$line"|cut -d, -f1)
        measurement_units=$(echo "$line"|cut -d, -f${field_no})
        if echo "${measurement_units}"|grep -q '~'; then
            value=$(echo "${measurement_units}"|cut -d~ -f1)
        else
            value=${measurement_units}
        fi

        if [ "X${new_key}" = "X${old_key}" ]; then
            # for the second record and later
            total=$(echo "${total},${value}"|awk -F, '{printf "%.2f",$1+$2;}')
            count=$(echo "${count},1"|awk -F, '{printf $1+$2;}')
            max=$(f_max "$max" "$value")
            min=$(f_min "$min" "$value")
        else
            # for the first record of the same key
            if [ "X${old_key}" != "X" ]; then
                # next key started
                if [ "${count}" -ge 4 ]; then
                    average=$(echo "${total},${max},${min},$count"|awk -F, '{printf "%.2f",($1-$2-$3)/($4-2);}')
                else
                    average=$(echo "${total},$count"|awk -F, '{printf "%.2f",$1/$2;}')
                fi
                if [ -z "${units}" ]; then
                    echo "${old_key}=${average}"
                else
                    echo "${old_key}=${average},${units}"
                fi
            fi
            total="${value}"
            max="${value}"
            min="${value}"
            old_key="${new_key}"
            count=1
            if echo "${measurement_units}"|grep -q '~'; then
                units=$(echo "${measurement_units}"|cut -d~ -f2)
            else
                units=""
            fi
        fi
    done < "${f_data}.sort"
    if [ "X${new_key}" != "X" ]; then
        if [ $count -ge 4 ]; then
            average=$(echo "${total},${max},${min},$count"|awk -F, '{printf "%.2f",($1-$2-$3)/($4-2);}')
        else
            average=$(echo "${total},$count"|awk -F, '{printf "%.2f",$1/$2;}')
        fi
        if [ -z "${units}" ]; then
            echo "${new_key}=${average}"
        else
            echo "${new_key}=${average},${units}"
        fi
    fi
    rm "${f_data}.sort"
}

## Description:
##   output the test result to console and add for lava-test-shell,
##   also write into one csv file for comparing manually
## Usage:
##    output_test_result $test_name $result [ $measurement [ $units ] ]
## Note:
##    G_RECORD_LOCAL_CSV: when this environment variant is set to "TRUE",
##         the result will be recorded in a csv file in the following path:
##              rawdata/final_result.csv
##    G_VERBOSE_OUTPUT: when this environment variant is set to "TRUE", and only it is TRUE,
##         the verbose informain about the result will be outputed
output_test_result(){
    test_name=$1
    result=$2
    measurement=$3
    units=$4

    if [ -z "${test_name}" ] || [ -z "$result" ]; then
        return
    fi
    output=""
    lava_paras=""
    output_csv=""
    if [ -z "$units" ]; then
        units="points"
    fi
    if [ -z "${measurement}" ]; then
        output="${test_name}=${result}"
        lava_paras="${test_name} ${result}"
    else
        output="${test_name}=${measurement} ${units}"
        lava_paras="${test_name} ${result} ${measurement} ${units}"
        output_csv="${test_name},${measurement} ${units}"
    fi

    echo "${lava_paras}" | tee -a "${RESULT_FILE}"

    if [ "X${G_VERBOSE_OUTPUT}" = "XTRUE" ];then
        echo "${output}"
    fi

    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        if [ -n "${output_csv}" ]; then
            echo "${output_csv}">>${F_RAW_DATA_CSV}
        fi
    fi
}

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
calculate_logcat_timestamp(){
    key_line=$1
    if [ -z "${key_line}" ]; then
        return
    fi

    year=$(date +%G)
    mmdd=$(echo "${key_line}" |awk '{printf "%s\n", $1}')
    hhmmss_ms=$(echo "${key_line}" |awk '{printf "%s\n", $2}')
    ms=$(echo "${hhmmss_ms}"|cut -d. -f2)
    hhmmss=$(echo "${hhmmss_ms}"|cut -d. -f1)
    hhmm=$(echo "${hhmmss}"|cut -d: -f1,2)
    ss=$(echo "${hhmmss}"|cut -d: -f3)
    mmddhhmm_ss=$(echo "${mmdd}${hhmm}${year}.${ss}"|tr -d ':-')
    sec=$(date -d "${mmddhhmm_ss}" +%s)
    echo "${sec}.${ms}"
}

getTimeStampFromLogcat(){
    key=$1
    if [ -z "${key}" ]; then
        return
    fi

    key_line=$(grep -i "${key}" "${LOG_LOGCAT_ALL}")
    calculate_logcat_timestamp "${key_line}"
}

getTimeStampFromLogcatDmesg(){
    key=$1
    if [ -z "${key}" ]; then
        return
    fi

    key_line=$(grep -i "${key}" "${LOG_LOGCAT_DMESG}")
    calculate_logcat_timestamp "${key_line}"
}

getBootTimeInfoFromProperty(){
    #"ro.runtime.firstboot"
    #"ro.boottime."
    # Time after boot in ns (via the CLOCK\_BOOTTIME clock) that the service was first started.
    while read -r line; do
        if ! echo "${line}"|grep -q "ro.boottime."; then
            continue
        fi

        line=$(echo "$line"|tr -d "[]:")
        key=$(echo "$line"|awk '{printf $1;}')
        value=$(echo "$line"|awk '{printf $2;}')
        output_test_result "${key}" "pass" "${value}" "ns"
    done < "${LOG_PROPERTY}"

    line_runtime_firstboot=$(grep "firstboot" "${LOG_PROPERTY}")
    if [ -n "${line_runtime_firstboot}" ]; then
        line_runtime_firstboot=$(echo "$line_runtime_firstboot"|tr -d "[]:")
        key=$(echo "$line_runtime_firstboot"|awk '{printf $1;}')
        value=$(echo "$line_runtime_firstboot"|awk '{printf $2;}')
        output_test_result "${key}" "pass" "${value}" "ns"
    fi
}

getTimeFromPropertyWithKey(){
    key="${1}"
    line=$(grep "\[${key}\]:" "${LOG_PROPERTY}")
    if [ -n "${line}" ]; then
        line=$(echo "$line"|tr -d "[]:")
        value=$(echo "$line"|awk '{printf $2;}')
        echo "${value}"
    fi
}

getTimestampWithMMDDAndHHMMSSMS(){
    mmdd="${1}"
    hhmmss_ms="${2}"

    year=$(date +%G)
    hhmmss=$(echo "${hhmmss_ms}"|cut -d. -f1)
    hhmm=$(echo "${hhmmss}"|cut -d: -f1,2)
    ss=$(echo "${hhmmss}"|cut -d: -f3)
    mmddhhmm_ss=$(echo "${mmdd}${hhmm}${year}.${ss}"|tr -d ':-')
            
    sec=$(date -d "${mmddhhmm_ss}" +%s)
    echo "${sec}.${ms}"
}

getBootTimeInfoFromLogs(){
    COLLECT_NO=$1
    LOG_LOGCAT_ALL="${dir_boottime_data}/logcat_all_${COLLECT_NO}.log"
    LOG_LOGCAT_DMESG="${dir_boottime_data}/logcat_dmesg_${COLLECT_NO}.log"
    LOG_PROPERTY="${dir_boottime_data}/prop_${COLLECT_NO}.log"

    # dmesg starts before all timers are initialized, so kernel reports time as 0.0.
    # we can't work around this without external time metering.
    # here we presume kernel message starts from 0
    KERNEL_BOOT_TIME_NS=$(getTimeFromPropertyWithKey "ro.boottime.init")
    if [ -n "${KERNEL_BOOT_TIME_NS}" ]; then
        KERNEL_BOOT_TIME=$(echo "${KERNEL_BOOT_TIME_NS}"| awk '{printf "%.3f",$1/1000/1000/1000;}')
        output_test_result "KERNEL_BOOT_TIME" "pass" "${KERNEL_BOOT_TIME}" "s"
    else
        CONSOLE_SECONDS_START=$(getTimeStampFromLogcatDmesg "Booting Linux on")
        CONSOLE_SECONDS_END=$(getTimeStampFromLogcatDmesg "Freeing unused kernel memory")
        if [ -n "${CONSOLE_SECONDS_END}" ] && [ -n "${CONSOLE_SECONDS_START}" ]; then
            KERNEL_BOOT_TIME=$(echo "${CONSOLE_SECONDS_END} ${CONSOLE_SECONDS_START}" | awk '{printf "%.3f",$1-$2;}')
            output_test_result "KERNEL_BOOT_TIME" "pass" "${KERNEL_BOOT_TIME}" "s"
        fi
    fi

    INIT_FIRST_STAGE_TIME_NS=$(getTimeFromPropertyWithKey "ro.boottime.init.first_stage")
    if [ -n "${INIT_FIRST_STAGE_TIME_NS}" ]; then
        INIT_FIRST_STAGE_TIME=$(echo "${INIT_FIRST_STAGE_TIME_NS}"| awk '{printf "%.3f",$1/1000/1000/1000;}')
        output_test_result "INIT_FIRST_STAGE_TIME" "pass" "${INIT_FIRST_STAGE_TIME}" "s"
    else
        POINT_FIRST_STAGE_START=$(getTimeStampFromLogcatDmesg "init .* init first stage started"|tail -n1)
        POINT_SECOND_STAGE_START=$(getTimeStampFromLogcatDmesg "init .* init second stage started"|tail -n1)
        if [ -n "${POINT_FIRST_STAGE_START}" ] && [ -n "${POINT_SECOND_STAGE_START}" ]; then
            INIT_FIRST_STAGE_TIME=$(echo "${POINT_SECOND_STAGE_START} ${POINT_FIRST_STAGE_START}" | awk '{printf "%.3f",$1-$2;}')
            output_test_result "INIT_FIRST_STAGE_TIME" "pass" "${INIT_FIRST_STAGE_TIME}" "s"
        fi
    fi

    POINT_SERVICE_BOOTANIM_START=$(getTimeStampFromLogcatDmesg "init .* Starting service 'bootanim'..."|tail -n1)
    POINT_SERVICE_BOOTANIM_END=$(getTimeStampFromLogcatDmesg "init .* Service 'bootanim'.* exited with status"|tail -n1)
    if [ -n "${POINT_SERVICE_BOOTANIM_END}" ] && [ -n "${POINT_SERVICE_BOOTANIM_START}" ]; then
        BOOTANIM_TIME=$(echo "${POINT_SERVICE_BOOTANIM_END} ${POINT_SERVICE_BOOTANIM_START}" | awk '{printf "%.3f",$1-$2;}')
        output_test_result "BOOTANIM_TIME" "pass" "${BOOTANIM_TIME}" "s"
    fi

    # use ro.boottime.init as the start of the init
    POINT_INIT_START_FROM_PROPERTY_NS=$(getTimeFromPropertyWithKey "ro.boottime.init")
    POINT_SERVICE_SURFACEFLINGER_START_FROM_PROPERTY_NS=$(getTimeFromPropertyWithKey "ro.boottime.surfaceflinger")
    if [ -n "${POINT_INIT_START_FROM_PROPERTY_NS}" ] && [ -n "${POINT_SERVICE_SURFACEFLINGER_START_FROM_PROPERTY_NS}" ]; then
        POINT_INIT_START_FROM_PROPERTY=$(echo "${POINT_INIT_START_FROM_PROPERTY_NS}"| awk '{printf "%.3f",$1/1000/1000/1000;}')
        POINT_SERVICE_SURFACEFLINGER_START_FROM_PROPERTY=$(echo "${POINT_SERVICE_SURFACEFLINGER_START_FROM_PROPERTY_NS}"| awk '{printf "%.3f",$1/1000/1000/1000;}')
        INIT_TO_SURFACEFLINGER_START_TIME=$(echo "${POINT_SERVICE_SURFACEFLINGER_START_FROM_PROPERTY} ${POINT_INIT_START_FROM_PROPERTY}" | awk '{printf "%.3f",$1-$2;}')
        output_test_result "INIT_TO_SURFACEFLINGER_START_TIME" "pass" "${INIT_TO_SURFACEFLINGER_START_TIME}" "s"
    else
        POINT_INIT_START=$(getTimeStampFromLogcatDmesg "Freeing unused kernel memory")
        POINT_SERVICE_SURFACEFLINGER_START=$(getTimeStampFromLogcatDmesg "init .* Starting service 'surfaceflinger'..."|tail -n1)
        if [ -n "${POINT_SERVICE_SURFACEFLINGER_START}" ] && [ -n "${POINT_INIT_START}" ]; then
            INIT_TO_SURFACEFLINGER_START_TIME=$(echo "${POINT_SERVICE_SURFACEFLINGER_START} ${POINT_INIT_START}" | awk '{printf "%.3f",$1-$2;}')
            output_test_result "INIT_TO_SURFACEFLINGER_START_TIME" "pass" "${INIT_TO_SURFACEFLINGER_START_TIME}" "s"
        fi
    fi

    ## When there are 2 lines of "Boot is finished",
    ## it mostly means that the surfaceflinger service restarted by some reason
    ## but here when there are multiple lines of "Boot is finished",
    ## use the last one line, and report the case later after checked all the logs
    SURFACEFLINGER_BOOT_TIME_INFO=$(grep "Boot is finished" "${LOG_LOGCAT_ALL}"|tail -n1)
    if [ -n "${SURFACEFLINGER_BOOT_TIME_INFO}" ]; then
        while echo "${SURFACEFLINGER_BOOT_TIME_INFO}"|grep -q -F "("; do
            SURFACEFLINGER_BOOT_TIME_INFO=$(echo "${SURFACEFLINGER_BOOT_TIME_INFO}"|cut -d\( -f2-)
        done
        SURFACEFLINGER_BOOT_TIME_MS=$(echo "${SURFACEFLINGER_BOOT_TIME_INFO}"|cut -d\  -f1)
        SURFACEFLINGER_BOOT_TIME=$(echo "${SURFACEFLINGER_BOOT_TIME_MS}" | awk '{printf "%.3f",$1/1000;}')
        output_test_result "SURFACEFLINGER_BOOT_TIME" "pass" "${SURFACEFLINGER_BOOT_TIME}" "s"
    fi


    # 01-01 00:00:51.269 I/AlarmManager(  536): Current time only 51269, advancing to build time 1593449504000  # Unit is MS
    # 06-29 16:51:44.003 D/SystemServerTiming(  536): StartAlarmManagerService took to complete: 6ms
    # 06-29 16:51:50.018 D/AlarmManagerService(  536): Setting time of day to sec=1595426411   #UNIT is SEC
    # 07-22 14:00:11.659 I/LaunchParamsPersister(  536): Didn't find launch param folder for user 0
    # 07-22 14:00:11.659 W/AlarmManagerService(  536): Unable to set rtc to 1595426411: Permission denied
    POINT_SURFACEFLINGER_BOOTED=$(getTimeStampFromLogcat "Boot is finished")
    POINT_LAUNCHER_DISPLAYED=$(getTimeStampFromLogcat "Displayed com.android.launcher")

    if [ -n "${POINT_SURFACEFLINGER_BOOTED}" ] && [ -n "${POINT_LAUNCHER_DISPLAYED}" ] && [ -n "${INIT_TO_SURFACEFLINGER_START_TIME}" ]; then
            min=$(echo "${POINT_LAUNCHER_DISPLAYED} ${POINT_SURFACEFLINGER_BOOTED}" | awk '{if ($1 < $2) printf $1; else print $2}')
            if [ "${min}" = "${POINT_SURFACEFLINGER_BOOTED}" ]; then
                ## In case timestamp of "Boot is finished" is smaller than timestamp of "Displayed com.android.launcher",
                ## we calculate TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED as the difference between
                ## "Boot is finished" and "Displayed com.android.launcher"

                # find the "Setting time of day to sec=" line between "Boot is finished" and "Displayed com.android.launcher"
                # Not sure if there is the case that "Setting time of day to" is called twice between "Boot is finished" and "Displayed com.android.launcher"
                #    01-01 00:00:24.024 D/AlarmManagerService(  397): Setting time of day to sec=1595059530
                #    07-18 08:05:30.003 D/SystemServerTiming(  397): StartAlarmManagerService took to complete: 11ms
                #    --
                #    07-18 08:05:39.722 I/SurfaceFlinger(  283): Boot is finished (23423 ms)
                #    07-18 08:05:39.725 I/ActivityManager(  397): About to commit checkpoint
                #    --
                #    07-18 08:05:44.837 I/ActivityTaskManager(  397): Displayed com.android.launcher3/.Launcher: +1s220ms
                #    07-18 08:05:44.972 D/Zygote  (  249): Forked child process 1258
                #    --
                #    07-18 08:05:45.654 D/AlarmManagerService(  397): Setting time of day to sec=1595481066
                #    07-23 05:11:06.127 D/DevicePolicyManager(  397): updateSystemUpdateFreezePeriodsRecord

                found_boot_is_finished=false
                SETTING_TIME_OF_DAY_SECS=0
                LAST_POINT_SETTING_TIME_OF_DAY="${POINT_SURFACEFLINGER_BOOTED}" # in case not found in between
                DURATION_FROM_SURFACEFLINGER_BOOTED=0
                grep -e 'Setting time of day to sec' -e 'Boot is finished' -e 'Displayed com.android.launcher' "${LOG_LOGCAT_ALL}"  > "${LOG_LOGCAT_ALL}.tmp"
                while read -r line; do
                    if echo "${line}"|grep -iq 'Displayed com.android.launcher'; then
                        POINT_LAUNCHER_DISPLAYED=$(calculate_logcat_timestamp "$line")
                        DURATION_FROM_SURFACEFLINGER_BOOTED=$(echo "${DURATION_FROM_SURFACEFLINGER_BOOTED}" "${POINT_LAUNCHER_DISPLAYED}" "${LAST_POINT_SETTING_TIME_OF_DAY}" | awk '{printf "%.3f", $1 + $2 - $3}')
                        break
                    fi

                    if ${found_boot_is_finished}; then
                        if echo "${line}"|grep -iq 'Setting time of day to sec='; then
                            POINT_SETTING_TIME_OF_DAY=$(calculate_logcat_timestamp "$line")
                            DURATION_FROM_SURFACEFLINGER_BOOTED=$(echo "${DURATION_FROM_SURFACEFLINGER_BOOTED}" "${POINT_SETTING_TIME_OF_DAY}" "${LAST_POINT_SETTING_TIME_OF_DAY}" | awk '{printf "%.3f", $1 + $2 - $3}')
                            SETTING_TIME_OF_DAY_SECS=$(echo "${line}" | cut -d= -f2)
                            LAST_POINT_SETTING_TIME_OF_DAY="${SETTING_TIME_OF_DAY_SECS}"
                        fi
                    elif echo "${line}"|grep -iq 'Boot is finished'; then
                        found_boot_is_finished=true
                    fi
                done <"${LOG_LOGCAT_ALL}.tmp"
                rm -f "${LOG_LOGCAT_ALL}.tmp"

                TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED="${DURATION_FROM_SURFACEFLINGER_BOOTED}"
            else
                ## In case timestamp of "Boot is finished" is greater than timestamp of "Displayed com.android.launcher",
                ## we set TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED as 0 since it is already included in the "Boot is finished" time
                TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED=0
            fi

            output_test_result "TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED" "pass" "${TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED}" "s"

            ANDROID_UI_SHOWN=$(echo "${INIT_TO_SURFACEFLINGER_START_TIME} ${SURFACEFLINGER_BOOT_TIME} ${TIME_FROM_SURFACEFLINER_BOOTED_TO_LAUNCHER_DISPLAYED}" | awk '{printf "%.3f",$1 + $2 + $3;}')
            output_test_result "ANDROID_UI_SHOWN" "pass" "${ANDROID_UI_SHOWN}" "s"
    fi

    if [ -n "${INIT_TO_SURFACEFLINGER_START_TIME}" ] && [ -n "${SURFACEFLINGER_BOOT_TIME}" ] ; then
        ANDROID_BOOT_TIME=$(echo "${INIT_TO_SURFACEFLINGER_START_TIME} ${SURFACEFLINGER_BOOT_TIME}" | awk '{printf "%.3f",$1 + $2;}')
        output_test_result "ANDROID_BOOT_TIME" "pass" "${ANDROID_BOOT_TIME}" "s"
    fi

    ## Special case about the timestamp:
    ##    12-31 23:59:59.989 E/ueventd (    0): LoadWithAliases was unable to load of:NmpuT<NULL>Cti,omap5-mpu
    ##    01-01 00:00:00.005 E/ueventd (    0): LoadWithAliases was unable to load of:NledsT<NULL>Cgpio-leds

    line_first_service_start=$(grep "init .* starting service '" "${LOG_LOGCAT_DMESG}"|head -n1)
    line_last_service_exit=$(grep "init .* Service .* exited with status" "${LOG_LOGCAT_DMESG}"|tail -n1)

    POINT_FIRST_SERVICE_START=$(getTimeStampFromLogcatDmesg "${line_first_service_start}")
    POINT_LAST_SERVICE_END=$(getTimeStampFromLogcatDmesg "${line_last_service_exit}")
    if [ -n "${POINT_LAST_SERVICE_END}" ] && [ -n "${POINT_FIRST_SERVICE_START}" ]; then
        ANDROID_SERVICES_TIME=$(echo "${POINT_LAST_SERVICE_END} ${POINT_FIRST_SERVICE_START}" | awk '{printf "%.3f",$1-$2;}')

        IS_ANDROID_SERVICES_TIME_LT_ZERO=$(echo "$ANDROID_SERVICES_TIME" |awk '{ if ($1 < 0) printf "true"; else print "false";}')
        if ${IS_ANDROID_SERVICES_TIME_LT_ZERO}; then
            # for case that the timestamps crosses years
            # move the first service start point to one day before,
            # and use the day of the first service start point as the day for the last service exit point
            mmdd_first_service_start=$(echo "${line_first_service_start}" |awk '{printf "%s\n", $1}')
            hhmmss_ms_first_service_start=$(echo "${line_first_service_start}" |awk '{printf "%s\n", $2}')
            hhmmss_ms_last_service_exit=$(echo "${line_last_service_exit}" |awk '{printf "%s\n", $2}')

            dd_first_service_start=$(echo "${mmdd_first_service_start}"|cut -d- -f2)
            dd_first_service_start=$((dd_first_service_start - 1))
            mm_first_service_start=$(echo "${mmdd_first_service_start}"|cut -d- -f1)
            mmdd_first_service_start_new="${mm_first_service_start}-${dd_first_service_start}"

            POINT_FIRST_SERVICE_START=$(getTimestampWithMMDDAndHHMMSSMS "${mmdd_first_service_start_new}" "${hhmmss_ms_first_service_start}")
            POINT_LAST_SERVICE_END=$(getTimestampWithMMDDAndHHMMSSMS "${mmdd_first_service_start}" "${hhmmss_ms_last_service_exit}")
            ANDROID_SERVICES_TIME=$(echo "${POINT_LAST_SERVICE_END} ${POINT_FIRST_SERVICE_START}" | awk '{printf "%.3f",$1-$2;}')
        fi
        output_test_result "ANDROID_SERVICES_TIME" "pass" "${ANDROID_SERVICES_TIME}" "s"
    fi

    if [ -n "${KERNEL_BOOT_TIME}" ] && [ -n "${ANDROID_BOOT_TIME}" ] ; then
        TOTAL_SECONDS=$(echo "${KERNEL_BOOT_TIME} ${ANDROID_BOOT_TIME}" | awk '{printf "%.3f",$1 + $2;}')
        output_test_result "TOTAL_BOOT_TIME" "pass" "${TOTAL_SECONDS}" "s"
    fi
}

OPERATION=$1
rm -rf "${RESULT_FILE}"
if [ "X${OPERATION}" = "XCOLLECT" ]; then
    G_VERBOSE_OUTPUT=FALSE
    G_RECORD_LOCAL_CSV=FALSE
    COLLECT_NO=$2
    mkdir -p ${dir_boottime_data}

    # shellcheck disable=SC2035
    logcat -d -v time *:V > "${dir_boottime_data}/logcat_all_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_LOGCAT_ALL_COLLECT" "pass"
    logcat -d -b events -v time > "${dir_boottime_data}/logcat_events_${COLLECT_NO}.log"
    logcat -d -b kernel -v time > "${dir_boottime_data}/logcat_dmesg_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_LOGCAT_EVENTS_COLLECT" "pass"
    su 0 dmesg > "${dir_boottime_data}/dmesg_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_DMESG_COLLECT" "pass"
    su 0 getprop > "${dir_boottime_data}/prop_${COLLECT_NO}.log"
    output_test_result "BOOTTIME_PROP_COLLECT" "pass"

    # make sure to write all files to disk
    sync

    echo "==============list of files under ${dir_boottime_data}/ starts from here:"
    ls -l ${dir_boottime_data}/*
    echo "==============list of files under ${dir_boottime_data}/ ends from here:"
elif [ "X${OPERATION}" = "XANALYZE" ]; then
    count=$2

    ## Check if there is any case that the surfaceflinger service
    ## was started several times
    if [ "${count}" -eq 0 ]; then
        i=0
    else
        i=1
    fi
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
            echo "==============content of the file ${LOG_LOGCAT_ALL} start from here:"
            cat ${LOG_LOGCAT_ALL}
            echo "==============content of the file ${LOG_LOGCAT_ALL} end from here:"

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
        # [   45.180397] init: Service 'bootanim' (pid 513) exited with status 0 oneshot service took 5.083000 seconds in background
        # [   45.191340] init: Sending signal 9 to service 'bootanim' (pid 513) process group...
        bootanim_lines=$(grep -c "init: Service 'bootanim'.* exited with status" "${LOG_DMESG}")
        if [ "${bootanim_lines}" -ne 1 ]; then
            echo "bootanim service seems to be started ${bootanim_lines} times in file: ${LOG_DMESG}"
            echo "Please check the status first"
            echo "==============content of the file ${LOG_DMESG} start from here:"
            cat ${LOG_DMESG}
            echo "==============content of the file ${LOG_DMESG} end from here:"
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
        if [ "${count}" -eq 0 ]; then
            i=0
        else
            i=1
        fi
        G_RESULT_NOT_RECORD=TRUE
        G_RECORD_LOCAL_CSV=TRUE
        export G_RECORD_LOCAL_CSV G_RESULT_NOT_RECORD
        while true; do
            if [ $i -gt "$count" ]; then
                break
            fi
            echo "=======Start to collect infomation for $i/$count iteration"
            getBootTimeInfoFromLogs ${i}
            getBootTimeInfoFromProperty ${i}
            echo "=======Finished collecting infomation for $i/$count iteration"
            i=$((i+1))
        done

        G_RESULT_NOT_RECORD=FALSE
        export G_RESULT_NOT_RECORD
        if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
            echo "=======Start to statistic infomation"
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
                output_test_result "${key}_avg" "pass" "${measurement}" "${units}"
            done < "${F_STATISTIC_DATA_CSV}"
            echo "=======Finished collecting statistic infomation"
        fi

        output_test_result "SERVICE_STARTED_ONCE" "pass"
    fi

    # set again for following output_test_result
    G_RECORD_LOCAL_CSV=FALSE
    cd ${local_tmp}|| exit 1
    tar -czvf boottime.tgz boottime
    output_test_result "BOOTTIME_ANALYZE" "pass"
else
    G_VERBOSE_OUTPUT=FALSE
    G_RECORD_LOCAL_CSV=FALSE
    export G_VERBOSE_OUTPUT G_RECORD_LOCAL_CSV
    echo "Not recognised operation"
    output_test_result "BOOTTIME" "fail"
fi
