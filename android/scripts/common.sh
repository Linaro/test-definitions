#!/system/bin/sh

G_LOOP_COUNT=12
G_RECORD_LOCAL_CSV=TRUE
F_RAW_DATA_CSV="/data/local/tmp/lava_test_shell_raw_data.csv"
F_STATISTIC_DATA_CSV="/data/local/tmp/lava_test_shell_statistic_data.csv"

## Description:
##    output the max value of the passed 2 parameters
## Usage:
##    f_max "${val1}" "${val2}"
## Example:
##    max=$(f_max "1.5" "2.0")
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

## Description:
##    output the min value of the passed 2 parameters
## Usage:
##    f_min "${val1}" "${val2}"
## Example:
##    min=$(f_min "1.5" "2.0")
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
    local units=""
    for line in $(cat "${f_data}"); do
        if ! echo "$line"|grep -q ,; then
            continue
        fi
        new_key=$(echo $line|cut -d, -f1)
        value=$(echo $line|cut -d, -f${field_no})
        if [ -z "${units}" ]; then
            units=$(echo ${value}|cut -d\  -f2)
        else
            value=$(echo ${value}|cut -d\  -f1)
        fi
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
        fi
    done
    if [ "X${new_key}" != "X" ]; then
        if [ $count -ge 4 ]; then
            average=$(echo "scale=2; ($total-$max-$min)/($count-2)"|bc)
        else
            average=$(echo "scale=2; $total/$count"|bc)
        fi
        if [ -z "${units}" ]; then
            echo "${new_key}=${average}"
        else
            echo "${new_key}=${average},${units}"
        fi
    fi
}

## Description:
##   output the test result to console and add for lava-test-shell,
##   also write into one csv file for comparing manually
## Usage:
##    output_test_result $test_name $result [ $measurement [ $units ] ]
## Note:
##    RECORD_RESULT_LOCAL: when this environment variant is set to "TRUE",
##         the result will be recorded in a csv file in the following path:
##              rawdata/final_result.csv
output_test_result(){
    local test_name=$1
    local result=$2
    local measurement=$3
    local units=$4

    if [ -z "${test_name}" ] || [ -z "$result" ]; then
        return
    fi
    local output=""
    local lava_paras=""
    local output_csv=""
    if [ -z "$units" ]; then
        units="points"
    fi
    if [ -z "${measurement}" ]; then
        output="${test_name}=${result}"
        lava_paras="${test_name} --result ${result}"
    else
        output="${test_name}=${measurement} ${units}"
        lava_paras="${test_name} --result ${result} --measurement ${measurement} --units ${units}"
        output_csv="${test_name},${measurement} ${units}"
    fi

    echo "${output}"

    local cmd="lava-test-case"
    if [ -n "$(which $cmd)" ];then
        $cmd ${lava_paras}
    else
        echo "$cmd ${lava_paras}"
    fi
    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        if [ -n "${output_csv}" ]; then
            echo "${output_csv}">>${F_RAW_DATA_CSV}
        fi
    fi
}

func_print_usage_common(){
    echo "$(basename $0) [--record-csv TRUE|others] [--loop-count LOOP_COUNT]"
    echo "     --record-csv: specify if record the result in csv format in file ${F_RAW_DATA_CSV}"
    echo "                   Only record the file when TRUE is specified."
    echo "     --loop-count: specify the number that how many times should be run for each application to get the average result, default is 12"
    echo "$(basename $0) [--help|-h]"
    echo "     print out this usage."
}

func_parse_parameters_common(){
    local para_loop_count=""
    while [ -n "$1" ]; do
        case "X$1" in
            X--record-csv)
                para_record_csv=$2
                shift 2
                ;;
            X--loop-count)
                para_loop_count=$2
                shift 2
                ;;
            X-h|X--help)
                func_print_usage_common
                exit 1
                ;;
            X-*)
                echo "Unknown option: $1"
                func_print_usage_common
                exit 1
                ;;
            X*)
                func_print_usage_common
                exit 1
                ;;
        esac
    done

    if [ -n "${para_loop_count}" ]; then
        local tmp_str=$(echo ${para_loop_count}|tr -d '[:digit:]')
        if [ -z "${tmp_str}" ]; then
            G_LOOP_COUNT=${para_loop_count}
        else
            echo "The specified LOOP_COUNT(${para_loop_count}) is not valid"
            exit 1
        fi
    fi

    if [ -n "${para_record_csv}" ] && [ "X${para_record_csv}" = "XTRUE" ];then
        G_RECORD_LOCAL_CSV=TRUE
    elif [ -n "${para_record_csv}" ];then
        G_RECORD_LOCAL_CSV=FALSE
    fi
}

## Description:
##   common framework to run test multiple times
##   also write result into one csv file for comparing manually
## Usage:
##    output_test_result $test_name $result [ $measurement [ $units ] ]
## Note:
##    RECORD_RESULT_LOCAL: when this environment variant is set to "TRUE",
##         the result will be recorded in a csv file in the following path:
##              rawdata/final_result.csv
run_test(){
    func_parse_parameters_common "$@"
    if [ "X{$G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        rm "${F_RAW_DATA_CSV}" "${F_STATISTIC_DATA_CSV}"
        mkdir -p $(dirname ${F_RAW_DATA_CSV})
    fi

    loop_index=0
    while [ ${loop_index} -lt ${G_LOOP_COUNT} ]; do
        if [ -n "${var_test_func}" ]; then
            ${var_test_func}
        fi
        loop_index=$((loop_index + 1))
    done

    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
#        statistic ${F_RAW_DATA_CSV} 2 |tee ${F_STATISTIC_DATA_CSV}
#        sed -i 's/=/,/' "${F_STATISTIC_DATA_CSV}"

        attach_cmd="lava-test-run-attach"
        if [ -n "$(which ${attach_cmd})" ]; then
            if [ -f "${F_RAW_DATA_CSV}" ]; then
                ${attach_cmd} ${F_RAW_DATA_CSV} text/plain
            fi
#            if [ -f "${F_STATISTIC_DATA_CSV}" ]; then
#                ${attach_cmd} ${F_STATISTIC_DATA_CSV} text/plain
#            fi
        fi
    fi
}
