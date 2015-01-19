#!/bin/bash

LOOP_COUNT=12
COLLECT_STREAMLINE="false"
BASE_URL="http://testdata.validation.linaro.org/apks/JavaBenchmark/pure-java-applications"
SERIAL=""
APPS="NULL,com.android.browser/.BrowserActivity,Browser"
APPS="${APPS} NULL,com.android.settings/.Settings,Settings"
APPS="${APPS} 01-3D_Volcano_Island.apk,com.omnigsoft.volcanoislandjava/.App,3D_Volcano_Island"
APPS="${APPS} 02-com.blong.jetboy_1.0.1.apk,com.blong.jetboy/.JetBoy,JetBoy"
APPS="${APPS} 03-HelloEffects.apk,com.example.android.mediafx/.HelloEffects,HelloEffects"
APPS="${APPS} 04-FREEdi_YouTube_Player_v2.2.apk,tw.com.freedi.youtube.player/.MainActivity,FREEdi_YouTube_Player"
APPS="${APPS} 17-GooglePlayBooks.apk,com.google.android.apps.books/.app.BooksActivity,GooglePlayBooks"
APPS="${APPS} 46-Zedge.apk,net.zedge.android/.activity.ControllerActivity,Zedge"
APPS="${APPS} 55-ShootBubbleDeluxe.apk,com.shootbubble.bubbledexlue/.FrozenBubble,ShootBubbleDeluxe"

dir_rawdata="rawdata"
dir_apks="apks"
f_starttime="${dir_rawdata}/activity_starttime.raw"
f_mem="${dir_rawdata}/activity_mem.raw"
f_cpu="${dir_rawdata}/activity_cpu.raw"
f_procrank="${dir_rawdata}/activity_procrank.raw"
f_stat="${dir_rawdata}/activity_stat.raw"
f_procmem="${dir_rawdata}/activity_procmem.raw"
f_maps="${dir_rawdata}/activity_maps.raw"

f_res_starttime="${dir_rawdata}/activity_starttime.csv"
f_res_mem="${dir_rawdata}/activity_mem.csv"
f_res_cpu="${dir_rawdata}/activity_cpu.csv"
f_res_procrank="${dir_rawdata}/activity_procrank.csv"
f_result="${dir_rawdata}/result.csv"

f_logcat="${dir_rawdata}/logcat.log"
f_logcat_event="${dir_rawdata}/logcat-events.log"

dir_streamline="${dir_rawdata}/streamline"
dir_screenshot="${dir_rawdata}/screenshots"

collect_raw_procmem_data(){
    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_procmem}"
    adb shell su 0 procmem ${pid} >> "${f_procmem}"
    echo "===pid=${pid}, package=${app_package}, count=${count} end" >> "${f_procmem}"

    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_procmem}_p"
    adb shell su 0 procmem -p ${pid} >> "${f_procmem}_p"
    echo "===pid=${pid}, package=${app_package}, count=${count} end" >> "${f_procmem}_p"

    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_procmem}_m"
    adb shell su 0 procmem -m ${pid} >> "${f_procmem}_m"
    echo "===pid=${pid}, package=${app_package}, count=${count} end" >> "${f_procmem}_m"
}

collect_raw_logcat_data(){
    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_logcat}"
    adb logcat -d -v time *:V >> "${f_logcat}"
    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_logcat}"
    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_logcat_event}"
    adb logcat -d -b events -v time *:V >> "${f_logcat_event}"
    echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_logcat_event}"
}

kill_process(){
    local proc=$1 && shift
    [ -z "${proc}" ] && return

    while adb shell ps | grep -q -E "\s+${proc}\s+"; do
        local pid=$(adb shell ps|grep -E "\s+${proc}\s+"|awk '{print $2}')
        if [ -n "${pid}" ]; then
            adb shell su 0 kill -9 "${pid}"
        fi
    done
    sleep 5
}

collect_streamline_data_before(){
    if [ "X${COLLECT_STREAMLINE}" != "Xtrue" ]; then
        return
    fi
    local app_name=$1 && shift
    if [ -z "${app_name}" ];then
        return
    fi
    local gatord_timeout="${1-10}" && shift

    kill_process "gatord"
    adb shell su 0 rm -fr /data/local/tmp/streamline
    adb shell mkdir /data/local/tmp/streamline
    cat >session.xml <<__EOF__
<?xml version="1.0" encoding="US-ASCII" ?>
<session version="1" title="${app_name}" target_path="@F" call_stack_unwinding="yes" parse_debug_info="yes" high_resolution="no" buffer_mode="streaming" sample_rate="normal" duration="${gatord_timeout}">
</session>
__EOF__
    adb push session.xml /data/local/tmp/streamline/session.xml
    echo "Gatord starts:$(date)"
    adb shell "su 0 gatord -s /data/local/tmp/streamline/session.xml -o /data/local/tmp/streamline/${app_name}.apc" &
    adb shell sleep 2
}

wait_kill_gatord_finish(){
    local gatord_timeout="${1-10}" && shift
    local proc="gatord"
    local count=1
    while adb shell ps | grep -q -E "\s+${proc}\s+"; do
        count=$((count+1))
        if [ ${count} -gt ${gatord_timeout} ]; then
            local pid=$(adb shell ps|grep -E "\s+${proc}\s+"|awk '{print $2}')
            if [ -n "${pid}" ]; then
                adb shell su 0 kill -9 "${pid}"
                sleep 2
            fi
        else
            sleep 1
        fi
    done
}

collect_streamline_data_post(){
    if [ "X${COLLECT_STREAMLINE}" != "Xtrue" ]; then
        return
    fi
    local app_name=$1 && shift
    if [ -z "${app_name}" ];then
        return
    fi
    echo "Wait gatord to finish:$(date)"
    wait_kill_gatord_finish
    echo "Gatord findihed:$(date)"
    adb shell su 0 chown -R shell:shell data/local/tmp/streamline
    adb pull /data/local/tmp/streamline/${app_name}.apc ${dir_streamline}/${app_name}.apc
    #streamline -analyze ${capture_dir}
    #streamline -report -function ${apd_f} |tee ${parent_dir}/streamlineReport.txt
}

collect_raw_data(){
    local pid=""
    rm -fr "${f_starttime}" "${f_mem}" "${f_cpu}" "${f_procrank}" "${f_stat}" "${f_procmem}" "${f_procmem}_m" "${f_procmem}_p"
    for apk in ${APPS}; do
        local app_apk=$(echo $apk|cut -d, -f1)
        local app_start_activity=$(echo $apk|cut -d, -f2)
        local app_package=$(echo $app_start_activity|cut -d\/ -f1)
        local app_name=$(echo $apk|cut -d, -f3)

        if [ "X${app_apk}" != "XNULL" ];then
            adb uninstall $app_package
        else
            kill_process "${app_package}"
        fi
        local count=0;
        while [ $count -lt ${LOOP_COUNT} ]; do
            # clean logcat
            adb logcat -c
            adb logcat -b events -c
            sleep 3

            # install apk
            if [ "X${app_apk}" != "XNULL" ];then
                adb install -r "$dir_apks/$app_apk"
            fi

            # catch the cpu information before start activity
            cpu_time_before=$(adb shell cat /proc/stat|grep 'cpu '|tr -d '\n')

            collect_streamline_data_before "${app_name}_${count}"

            # start activity
            adb shell am start -W -S $app_start_activity

            # wait for activity to be displayed int logcat
            while ! adb logcat -d|grep -q "Displayed $app_start_activity"; do
                sleep 1
            done
            collect_streamline_data_post "${app_name}_${count}"

            # get cpu information
            cpu_time_after=$(adb shell cat /proc/stat|grep 'cpu '|tr -d '\n')
            echo "${app_package},${cpu_time_before},${cpu_time_after}" >>"${f_cpu}"

            # get activity start time information
            adb logcat -d|grep "Displayed ${app_start_activity}" >>"${f_starttime}"

            # get memory info
            adb shell ps|grep "${app_package}" >>"${f_mem}"
            adb shell su 0 procrank|grep "${app_package}" >> "${f_procrank}"

            pid=$(adb shell ps|grep ${app_package}|awk '{print $2}')
            if [ -n "${pid}" ]; then
                adb shell su 0 cat /proc/${pid}/stat >> "${f_stat}"
                echo "===pid=${pid}, package=${app_package}, count=${count} start" >> "${f_maps}"
                adb shell su 0 cat /proc/${pid}/maps >> "${f_maps}"
                echo "===pid=${pid}, package=${app_package}, count=${count} end" >> "${f_maps}"

                collect_raw_procmem_data
            fi


            # capture screen shot
            adb shell screencap /data/local/tmp/app_screen.png
            adb pull /data/local/tmp/app_screen.png ${dir_screenshot}/${app_package}_${count}.png

            # uninstall or kill the app process
            if [ "X${app_apk}" != "XNULL" ];then
                adb uninstall $app_package
            else
                kill_process "${app_package}"
            fi
            echo "" >>"${f_starttime}"
            echo "" >>"${f_mem}"
            echo "" >>"${f_cpu}"
            collect_raw_logcat_data
            count=$((count + 1 ))
        done
    done
}

format_starttime_raw_data(){
    sed '/^\s*$/d' "${f_starttime}" |tr -s ' '|tr -d '\r'|sed 's/^.*Displayed\ //'|sed 's/(.*$//' |sed 's/: +/,/' >"${f_res_starttime}.tmp"
    for line in $(cat "${f_res_starttime}.tmp"); do
        local app_pkg=$(echo $line|cut -d, -f1)
        local app_time=$(echo $line|cut -d, -f2|sed 's/ms//g')
        # assumed no minute here
        if echo $app_time|grep -q 's'; then
            local app_sec=$(echo $app_time|cut -ds -f1)
            local app_msec=$(echo $app_time|cut -ds -f2)
            app_time=$((app_sec * 1000 + app_msec))
        fi
        echo "${app_pkg},${app_time}" >>"${f_res_starttime}"
    done
    rm -f "${f_res_starttime}.tmp"
}

format_mem_raw_data(){
    sed '/^\s*$/d' "${f_mem}" |tr -s ' '|tr -d '\r'|awk '{printf "%s,%s,%s\n", $9, $4, $5;}' >"${f_res_mem}"
}

calculate_field_value(){
    local line_val=$1 && shift
    local field_no=$1 && shift
    [ -z "${line_val}" ] && return
    [ -z "${field_no}" ] && return

    local val1=$(echo "${line_val}"|cut -d, -f${field_no})
    local field2_no=$(echo "${field_no}+10"|bc)
    local val2=$(echo "${line_val}"|cut -d, -f${field2_no})
    local val=$(echo "${val2}-${val1}"|bc)
    echo "${val}"
}

format_cputime(){
    local f_data=$1 && shift
    if ! [ -f "$f_data" ]; then
        return
    fi
    rm -fr "${f_data}_2nd"
    for line in $(cat "${f_data}"); do
        if ! echo "$line"|grep -q ,; then
            continue
        fi
        local key=$(echo $line|cut -d, -f1)

        local val_user=$(calculate_field_value "$line" 2)
        local val_nice=$(calculate_field_value "$line" 3)

        local val_system=$(calculate_field_value "$line" 4)
        local val_idle=$(calculate_field_value "$line" 5)
        local val_io_wait=$(calculate_field_value "$line" 6)
        local val_irq=$(calculate_field_value "$line" 7)
        local val_softirq=$(calculate_field_value "$line" 8)

        local val_total_user=$(echo "scale=2; ${val_user}+${val_nice}"|bc)
        local val_total_system=$(echo "scale=2; ${val_system}+${val_irq}+${val_softirq}"|bc)
        local val_total_idle=$val_idle
        local val_total_iowait=$val_io_wait
        local val_total=$(echo "scale=2; ${val_total_system}+${val_total_user}+${val_total_idle}+${val_total_iowait}"|bc)

        local percent_user=$(echo "scale=2; $val_total_user*100/$val_total"|bc)
        local percent_sys=$(echo "scale=2; $val_total_system*100/$val_total"|bc)
        local percent_idle=$(echo "scale=2; $val_total_idle*100/$val_total"|bc)
        echo "$key,$percent_user,$percent_sys,$percent_idle" >> "${f_data}_2nd"
    done
}

format_cpu_raw_data(){
    sed '/^\s*$/d' "${f_cpu}" |tr -d '\r'|tr -s ' '|tr ' ' ','|sed 's/cpu,//g' >"${f_res_cpu}"
    format_cputime "${f_res_cpu}"
}

format_procrank_data(){
    sed '/^\s*$/d' "${f_procrank}" |sed 's/^\s*//'|tr -d '\r'|awk '{printf("%s,%s,%s,%s,%s\n", $6, $2, $3, $4, $5)}'|tr -d 'K'>"${f_res_procrank}"
}

format_procmem_data(){
    sed 's/^\s*//' "${f_procmem}" |tr -s ' '|tr ' ' ',' >"${f_procmem}.csv"
    sed 's/^\s*//' "${f_procmem}_p" |tr -s ' '|tr ' ' ',' >"${f_procmem}_p.csv"
    sed 's/^\s*//' "${f_procmem}_m" |tr -s ' '|tr ' ' ',' >"${f_procmem}_m.csv"
}

format_raw_data(){
    rm -fr ${f_res_starttime} ${f_res_mem} ${f_res_cpu} ${f_res_procrank}

    format_starttime_raw_data
    format_mem_raw_data
    format_cpu_raw_data
    format_procrank_data
}

set_browser_homepage(){
    pref_file="com.android.browser_preferences.xml"
    pref_dir="/data/data/com.android.browser/shared_prefs/"
    pref_content='<?xml version="1.0" encoding="utf-8" standalone="yes" ?>
<map>
    <boolean name="enable_hardware_accel_skia" value="false" />
    <boolean name="autofill_enabled" value="true" />
    <string name="homepage">about:blank</string>
    <boolean name="last_paused" value="false" />
    <boolean name="debug_menu" value="false" />
</map>'

    # start browser for the first time to genrate preference file
    adb shell am start com.android.browser/.BrowserActivity
    sleep 5
    user_grp=$(adb shell su 0 ls -l "${pref_dir}/${pref_file}"|awk '{printf "%s:%s", $2, $3}')
    kill_process "com.android.browser"

    echo "${pref_content}" > "${pref_file}"
    adb push "${pref_file}" "/data/local/tmp/${pref_file}"
    adb shell su 0 cp "/data/local/tmp/${pref_file}" "${pref_dir}/${pref_file}"
    adb shell su 0 chown ${user_grp} "${pref_dir}/${pref_file}"
    adb shell su 0 chmod 660 "${pref_dir}/${pref_file}"

    adb shell am start com.android.browser/.BrowserActivity
    sleep 5
    kill_process "com.android.browser"
    adb shell am start com.android.browser/.BrowserActivity
    sleep 5
    kill_process "com.android.browser"
}

get_file_with_base_url(){
    local file_name=$1 && shift
    if [ -z "$file_name" ]; then
        echo "The file name must be specified."
        return 1
    fi

    if [ -f "${dir_apks}/${file_name}" ]; then
        echo "The file($file_name) already exists."
        return 0
    fi
    mkdir -p "${dir_apks}"
    case "X${BASE_URL}" in
        "Xscp://"*)
            # like scp://yongqin.liu@testdata.validation.linaro.org/home/yongqin.liu
            apk_url="${BASE_URL}/${file_name}"
            url_no_scp=`echo ${apk_url}|sed 's/^\s*scp\:\/\///'|sed 's/\//\:\//'`
            scp "${url_no_scp}" "${dir_apks}/${file_name}"
            if [ $? -ne 0 ]; then
                echo "Failed to get the apk(${file_name}) with ${BASE_URL}"
                return 1
            fi
            ;;
        "Xssh://"*)
            git clone "${BASE_URL}" "${dir_apks}"
            if [ $? -ne 0 ]; then
                echo "Failed to get the apks with ${BASE_URL}"
                return 1
            fi
            ;;
        "Xhttp://"*)
            wget "${BASE_URL}/${file_name}" -O "${dir_apks}/${file_name}"
            if [ $? -ne 0 ]; then
                echo "Failed to get the apks with ${BASE_URL}"
                return 1
            fi
            ;;
        "X"*)
            echo "Failed to get the file($file_name)."
            echo "The schema of the ${BASE_URL} is not supported now!"
            return 1
            ;;
    esac

    return 0
}

get_apks(){
    for apk in ${APPS}; do
        local app_apk=$(echo $apk|cut -d, -f1)
        app_apk=$(echo "$app_apk"|sed 's/\s*$//' |sed 's/^\s*//')
        if [ -z "${app_apk}" ]; then
            echo "Either the apk file name or NULL must be specified for one application"
            echo "This application configuration is not valid: $apk"
            return 1
        fi
        if [ "X${app_apk}" = "XNULL" ]; then
            continue
        fi
        get_file_with_base_url "${app_apk}" || return 1
    done
    return 0
}

prepare(){
    if [ -n "${SERIAL}" ];then
        ANDROID_SERIAL=$SERIAL
        export ANDROID_SERIAL
    fi

    rm -fr ${dir_rawdata}
    mkdir -p "${dir_screenshot}" "${dir_streamline}"

    get_apks || exit 1

    if echo "$APPS"|grep -q "com.android.browser"; then
        set_browser_homepage
    fi

    adb shell su 0 svc power stayon true
}

f_max(){
    local val1=$1 && shift
    local val2=$1 && shift
    [ -z "$val1" ] && return $val2
    [ -z "$val2" ] && return $val1

    local compare=$(echo "$val1>$val2"|bc)
    if [ "X$compare" = "X1" ];then
        echo $val1
    else
        echo $val2
    fi
}

f_min(){
    local val1=$1 && shift
    local val2=$1 && shift
    [ -z "$val1" ] && return $val1
    [ -z "$val2" ] && return $val2

    local compare=$(echo "$val1<$val2"|bc)
    if [ "X$compare" = "X1" ];then
        echo $val1
    else
        echo $val2
    fi
}

statistic(){
    local f_data=$1 && shift
    if ! [ -f "$f_data" ]; then
        return
    fi
    local field_no=$1 && shift
    if [ -z "$field_no" ]; then
        field_no=2
    fi
    local total=0
    local max=0
    local min=0
    local old_key=""
    local new_key=""
    local count=0
    for line in $(cat "${f_data}"); do
        if ! echo "$line"|grep -q ,; then
            continue
        fi
        new_key=$(echo $line|cut -d, -f1)
        value=$(echo $line|cut -d, -f${field_no})
        if [ "X${new_key}" = "X${old_key}" ]; then
            total=$(echo "scale=2; ${total}+${value}"|bc -s)
            count=$(echo "$count + 1"|bc)
            max=$(f_max "$max" "$value")
            min=$(f_min "$min" "$value")
        else
            if [ "X${old_key}" != "X" ]; then
                if [ $count -ge 4 ]; then
                    average=$(echo "scale=2; ($total-$max-$min)/($count-2)"|bc)
                else
                    average=$(echo "scale=2; $total/$count"|bc)
                fi
                echo "$old_key=$average"
            fi
            total="${value}"
            max="${value}"
            min="${value}"
            old_key="${new_key}"
            count=1
        fi
    done
    if [ "X${new_key}" != "X" ]; then
        if [ $count -ge 4 ]; then
            average=$(echo "scale=2; ($total-$max-$min)/($count-2)"|bc)
        else
            average=$(echo "scale=2; $total/$count"|bc)
        fi
        echo "$new_key=$average"
    fi
}

statistic_data(){
    rm -fr "${f_result}"
    statistic "$f_res_starttime" 2|sed "s/^/starttime_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_mem}" 2|sed "s/^/ps_vss_/" |tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_mem}" 3|sed "s/^/ps_rss_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_procrank}" 2|sed "s/^/proc_vss_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_procrank}" 3|sed "s/^/proc_rss_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_procrank}" 4|sed "s/^/proc_pss_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_procrank}" 5|sed "s/^/proc_uss_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_cpu}_2nd" 2|sed "s/^/cpu_user_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_cpu}_2nd" 3|sed "s/^/cpu_sys_/"|tee -a "${f_result}"
    echo "--------------------------------"
    statistic "${f_res_cpu}_2nd" 4|sed "s/^/cpu_idle_/"|tee -a "${f_result}"
    sed -i 's/=/,/' "${f_result}"
}

print_usage(){
    echo "$(basename $0) --base-url BASE_URL [--serial serial_no] [--loop-count LOOP_COUNT] [--streamline true|false] APP_CONFIG_LIST ..."
    echo "     --serial: specify serial number for the device"
    echo "     --base-url: specify the based url where the apks will be gotten from"
    echo "     --loop-count: specify the number that how many times should be run for each application to get the average result, default is 12"
    echo "     --streamline: specify if we need to collect the streamline data, true amd false can be specified, default is fasle"
    echo "     APP_CONFIG_LIST: specify the configurations for each application as following format:"
    echo "             APK_NAME,PACKAGE_NAME/APP_ACTIVITY,APP_NICKNAME"
    echo "         APK_NAME: the apk file name which we will get from the BASE_URL specified by --base-url option."
    echo "                   if NULL is specified, it means this APK is a system apk, no need to get from BASE_URL"
    echo "         APP_PACKAGE: the package name for this application"
    echo "         APP_ACTIVITY: the activity name will be started for this application"
    echo "         APP_NICKNAME: a nickname for this application, should only contain alphabet and digits"
}

parse_parameters(){
    while [ -n "$1" ]; do
        case "X$1" in
            X--base-url)
                BASE_URL=$2
                shift 2
                ;;
            X--streamline)
                COLLECT_STREAMLINE=$2
                shift 2
                ;;
            X--loop-count)
                LOOP_COUNT=$2
                shift 2
                ;;
            X--serial)
                SERIAL=$2
                shift 2
                ;;
            X-h|X--help)
                print_usage
                exit 1
                ;;
            X-*)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
            X*)
                PARA_APPS="${PARA_APPS} $1"
                shift 1
                ;;
        esac
    done

    if [ -z "${BASE_URL}" ]; then
        echo "BASE_URL information must be specified."
        exit 1
    fi
    if [ -z "$LOOP_COUNT" ] || ! echo "${LOOP_COUNT}"| grep -q -P '^\d+$'; then
        echo "The specified LOOP_COUNT($LOOP_COUNT) is not valid"
        exit 1
    fi

    PARA_APPS=$(echo "$PARA_APPS"|sed 's/\s*$//' |sed 's/^\s*//')
    if [ -n "$PARA_APPS" ]; then
        APPS="${PARA_APPS}"
    fi
}

main(){
    parse_parameters "$@"
    prepare
    collect_raw_data
    format_raw_data
    statistic_data
    rm -fr rawdata.zip
    zip -r rawdata.zip "${dir_rawdata}"
}

main "$@"
