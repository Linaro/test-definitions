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

    for res_line in $(${cmd} |tr ' ' '_'); do
        local test_case_id=$(echo $res_line|cut -d: -f1|tr -c '[:alnum:]:.' '_'|tr -s '_' |sed 's/_$//')
        local measurement_units=$(echo $res_line|cut -d: -f2)
        local measurement=$(echo ${measurement_units}|cut -d_ -f2)
        local units=$(echo ${measurement_units}|cut -d_ -f2)
        output_test_result "${prefix}${test_case_id}" "pass" "${measurement}" "seconds"
    done
}

test_func(){
    stringbench="/system/xbin/stringbench"
    stringbench64="/system/xbin/stringbench64"
    test_stringbench "${stringbench}" "32Bit"
    test_stringbench "${stringbench64}" "64Bit"
}

main(){
    var_test_func="test_func"
    run_test "$@"
}

main "$@"
