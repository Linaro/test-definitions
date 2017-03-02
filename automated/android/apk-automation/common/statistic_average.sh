#!/bin/bash

## Description:
##    output the max value of the passed 2 parameters
## Usage:
##    f_max "${val1}" "${val2}"
## Example:
##    max=$(f_max "1.5" "2.0")
f_max(){
    local val1=$1
    local val2=$2
    [ -z "$val1" ] && echo "$val2"
    [ -z "$val2" ] && echo "$val1"

    local compare
    compare=$(echo "$val1>$val2"|bc)
    if [ "X$compare" = "X1" ];then
        echo "$val1"
    else
        echo "$val2"
    fi
}

## Description:
##    output the min value of the passed 2 parameters
## Usage:
##    f_min "${val1}" "${val2}"
## Example:
##    min=$(f_min "1.5" "2.0")
f_min(){
    local val1=$1
    local val2=$2
    [ -z "$val1" ] && echo "$val1"
    [ -z "$val2" ] && echo "$val2"

    local compare
    compare=$(echo "$val1<$val2"|bc)
    if [ "X$compare" = "X1" ];then
        echo "$val1"
    else
        echo "$val2"
    fi
}

standard_deviation_error(){
    local average=$1
    if [ -z "${average}" ]; then
        return
    fi
    shift

    local values=$1
    if [ -z "${values}" ]; then
        return
    fi
    shift
    local deviations_sum=0
    local count=0
    for s_value in $values ; do
        s_deviation=$(echo "${average},${s_value}"|awk -F, '{printf "%.2f",($2-$1)^2;}')
        deviations_sum=$(echo "${deviations_sum},${s_deviation}"|awk -F, '{printf "%.2f",$1+$2;}')
        count=$(echo "${count},1"|awk -F, '{printf $1+$2;}')
    done
    local deviation
    deviation=$(echo "${deviations_sum},${count}"|awk -F, '{printf "%.2f",sqrt($1/$2);}')
    local std_err
    std_err=$(echo "${deviation},${count}"|awk -F, '{printf "%.2f",$1/sqrt($2);}')
    echo "${deviation},${std_err}"
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
    local f_data=$1
    if ! [ -f "$f_data" ]; then
        return
    fi
    local field_no=$2
    if [ -z "$field_no" ]; then
        field_no=2
    fi

    local units_field_no=$3
    local units=""

    local total=0
    local old_key=""
    local new_key=""
    local count=0
    local values=""
    # shellcheck disable=SC2013
    for line in $(cat "${f_data}"); do
        if ! echo "$line"|grep -q ,; then
            continue
        fi
        new_key=$(echo "${line}" | cut -d, -f1)
        value=$(echo "${line}" | cut -d, -f${field_no})
        if [ "X${new_key}" = "X${old_key}" ]; then
            total=$(echo "${total},${value}" | awk -F, '{printf "%.2f",$1+$2;}')
            values="${values} ${value}"
            count=$(echo "$count + 1"|bc)
        else
            if [ "X${old_key}" != "X" ]; then
                local average
                average=$(echo "${total},${count}" | awk -F, '{printf "%.2f",$1/$2;}')
                local sigma_stderr
                sigma_stderr=$(standard_deviation_error "${average}" "${values}")
                local sigma
                sigma=$(echo "${sigma_stderr}" | cut -d, -f1)
                local std_err
                std_err=$(echo "${sigma_stderr}" | cut -d, -f2)
                if [ -z "${units}" ]; then
                    echo "${old_key}=${average}"
                    echo "${old_key}_sigma=${sigma}"
                    echo "${old_key}_std_err=${std_err}"
                else
                    echo "${old_key}=${average},${units}"
                    echo "${old_key}_sigma=${sigma},${units}"
                    echo "${old_key}_std_err=${std_err},${units}"
                fi
            fi
            total="${value}"
            values="${value}"
            old_key="${new_key}"
            count=1
            if [ -n "${units_field_no}" ]; then
                units=$(echo "${line}" | cut -d, -f"${units_field_no}")
            fi
        fi
    done
    if [ "X${new_key}" != "X" ]; then
        local average
        average=$(echo "${total},${count}" | awk -F, '{printf "%.2f",$1/$2;}')
        local sigma_stderr
        sigma_stderr=$(standard_deviation_error "${average}" "${values}")
        local sigma
        sigma=$(echo "${sigma_stderr}" | cut -d, -f1)
        local std_err
        std_err=$(echo "${sigma_stderr}" | cut -d, -f2)
        if [ -z "${units}" ]; then
            echo "${old_key}=${average}"
            echo "${old_key}_sigma=${sigma}"
            echo "${old_key}_std_err=${std_err}"
        else
            echo "${old_key}=${average},${units}"
            echo "${old_key}_sigma=${sigma},${units}"
            echo "${old_key}_std_err=${std_err},${units}"
        fi
    fi
}
