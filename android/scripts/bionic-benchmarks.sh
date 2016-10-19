#!/system/bin/sh

local_file_path="$0"
local_file_parent=$(cd $(dirname ${local_file_path}); pwd)
. ${local_file_parent}/common.sh

test_bionic_benchmark(){
    local arch=$1
    local cmd=""
    if [ "X$arch" = "X32" ]; then
        cmd="/data/benchmarktest/bionic-benchmarks/bionic-benchmarks32"
    elif [ "X$arch" = "X64" ]; then
        cmd="/data/benchmarktest64/bionic-benchmarks/bionic-benchmarks64"
    else
        echo "The specified $arch is not specified!"
        return
    fi
    chmod +x ${cmd}
    if [ -n "$(which ${cmd})" ]; then
        for  res_line in $(${cmd} --color_print=false |grep "BM_"|tr -s ' '|tr ' ' ','); do
            local key=$(echo $res_line|cut -d, -f1|tr '/' '_')
            local iterations=$(echo $res_line|cut -d, -f2)
            local ns_time=$(echo $res_line|cut -d, -f3)
            local throughput=$(echo $res_line|cut -d, -f4)
            local throughput_units=$(echo $res_line|cut -d, -f5)
            output_test_result "${arch}_${key}" "pass"
            output_test_result "${arch}_${key}_time" "pass" "${ns_time}"  "ns/op"
            if [ -n "${throughput_units}" ];then
                output_test_result "${arch}_${key}_throught" "pass" "${throughput}" "${throughput_units}"
            fi
        done
    fi
}

test_func(){
    test_bionic_benchmark "64"
    test_bionic_benchmark "32"
}

main(){
    var_test_func="test_func"
    run_test "$@"
}

main "$@"
