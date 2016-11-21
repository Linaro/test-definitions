#!/system/bin/sh

G_LOOP_COUNT=12
G_RECORD_LOCAL_CSV=TRUE
G_VERBOSE_OUTPUT=FALSE
G_RESULT_NOT_RECORD=FALSE
F_RAW_DATA_CSV="/data/local/tmp/lava_test_shell_raw_data.csv"
F_STATISTIC_DATA_CSV="/data/local/tmp/lava_test_shell_statistic_data.csv"
var_test_func=""

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
            total=$(echo "${total},${value}"|awk -F, '{printf "%.2f",$1+$2;}')
            count=$(echo "${count},1"|awk -F, '{printf $1+$2;}')
            max=$(f_max "$max" "$value")
            min=$(f_min "$min" "$value")
        else
            if [ "X${old_key}" != "X" ]; then
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
        lava_paras="${test_name} --result ${result}"
    else
        output="${test_name}=${measurement} ${units}"
        lava_paras="${test_name} --result ${result} --measurement ${measurement} --units ${units}"
        output_csv="${test_name},${measurement} ${units}"
    fi

    if [ "X${G_VERBOSE_OUTPUT}" = "XTRUE" ];then
        echo "${output}"
    fi

    cmd="lava-test-case"
    if [ "X${G_RESULT_NOT_RECORD}" = "XFALSE" ] && [ -n "$(which $cmd)" ];then
        # shellcheck disable=SC2086
        $cmd ${lava_paras}
    elif [ "X${G_VERBOSE_OUTPUT}" = "XTRUE" ];then
        echo "$cmd ${lava_paras}"
    fi
    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        if [ -n "${output_csv}" ]; then
            echo "${output_csv}">>${F_RAW_DATA_CSV}
        fi
    fi
}

func_print_usage_common(){
    script_name=$(basename "$0")
    echo "${script_name} [--record-csv TRUE|others] [--loop-count LOOP_COUNT]"
    echo "     --record-csv: specify if record the result in csv format in file ${F_RAW_DATA_CSV}"
    echo "                   Only record the file when TRUE is specified."
    echo "     --loop-count: specify the number that how many times should be run for each application to get the average result, default is 12"
    echo "     --verbose-output: output the result and lava-test-case command for each test case each time it is run"
    echo "${script_name} [--help|-h]"
    echo "     print out this usage."
}

func_parse_parameters_common(){
    para_loop_count=""
    while [ -n "$1" ]; do
        case "X$1" in
            X--record-csv)
                para_record_csv=$2
                if [ -z "${para_record_csv}" ]; then
                    echo "Please specify the value for --record-csv option"
                    exit 1
                fi
                shift 2
                ;;
            X--verbose-output)
                para_verbose_output=$2
                if [ -z "${para_verbose_output}" ]; then
                    echo "Please specify the value for --verbose-output option"
                    exit 1
                fi
                shift 2
                ;;
            X--loop-count)
                para_loop_count=$2
                if [ -z "${para_loop_count}" ]; then
                    echo "Please specify the value for --loop-count option"
                    exit 1
                fi
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
        tmp_str=$(echo "${para_loop_count}"|tr -d '[:digit:]')
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

    if [ -n "${para_verbose_output}" ] && [ "X${para_verbose_output}" = "XTRUE" ];then
        G_VERBOSE_OUTPUT=TRUE
    elif [ -n "${para_record_csv}" ];then
        G_VERBOSE_OUTPUT=FALSE
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
    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        [ -f "${F_RAW_DATA_CSV}" ] && rm "${F_RAW_DATA_CSV}"
        [ -f "${F_STATISTIC_DATA_CSV}" ] && rm "${F_STATISTIC_DATA_CSV}"
        mkdir -p "$(dirname ${F_RAW_DATA_CSV})"
    fi

    loop_index=0
    while [ "${loop_index}" -lt "${G_LOOP_COUNT}" ]; do
        if [ -n "${var_test_func}" ]; then
            ${var_test_func}
        fi
        loop_index=$((loop_index + 1))
    done

    if [ "X${G_RECORD_LOCAL_CSV}" = "XTRUE" ]; then
        statistic ${F_RAW_DATA_CSV} 2 |tee ${F_STATISTIC_DATA_CSV}
        sed -i 's/=/,/' "${F_STATISTIC_DATA_CSV}"

        attach_cmd="lava-test-run-attach"
        if [ -n "$(which ${attach_cmd})" ]; then
            if [ -f "${F_RAW_DATA_CSV}" ]; then
                ${attach_cmd} ${F_RAW_DATA_CSV} text/plain
            fi
            if [ -f "${F_STATISTIC_DATA_CSV}" ]; then
                ${attach_cmd} ${F_STATISTIC_DATA_CSV} text/plain
            fi
        fi
    fi
}
