#!/system/bin/sh

local_file_path="$0"
local_file_parent=$(cd $(dirname ${local_file_path}); pwd)
. ${local_file_parent}/common.sh

test_stringbench(){
    local cmd=$1 && shift
    local prefix=$1 && shift
    if [ -z "${cmd}" ]; then
        return
    fi
    if [ ! -x "${cmd}" ]; then
        return
    fi
    if [ -n "$prefix" ]; then
        prefix="${prefix}_"
    fi
    
    local oldkey=""
    local newkey=""
    local value_line=""=
    for res_line in $(${cmd} |tr -d ' '); do
        if echo "${res_line}"|grep -q '^b_'; then
            if [ -n "${oldkey}" ] && [ -n "${value_line}" ]; then
               local time_value=$(echo ${value_line}|cut -d, -f1|cut -d: -f2)
               local virt_value=$(echo ${value_line}|cut -d, -f2|cut -d: -f2)
               local res_value=$(echo ${value_line}|cut -d, -f3|cut -d: -f2)
               local dirty_value=$(echo ${value_line}|cut -d, -f4|cut -d: -f2)
               output_test_result "${prefix}${oldkey}_time" "pass" "${time_value}" "seconds"
               output_test_result "${prefix}${oldkey}_virt" "pass" "${virt_value}" "kB"
               output_test_result "${prefix}${oldkey}_res" "pass" "${res_value}" "kB"
               output_test_result "${prefix}${oldkey}_dirty" "pass" "${dirty_value}" "kB"
            fi
            newkey=$(echo $res_line|tr -c '[:alnum:]' '_'|tr -s '_' |sed 's/_$//')
            value_line=""
            oldkey=${newkey}
            continue
        fi

        if echo "${res_line}"|grep -q '^time:'; then
            value_line="${res_line}"
            continue
        fi
    done
}

test_func(){
    stringbench="/system/xbin/libcbench"
    stringbench64="/system/xbin/libcbench64"
    test_stringbench "${stringbench}" "32Bit"
    test_stringbench "${stringbench64}" "64Bit"
}

main(){
    var_test_func="test_func"
    run_test "$@"
}

main "$@"
