#!/system/bin/sh

local_file_path="$0"
local_file_parent=$(cd $(dirname ${local_file_path}); pwd)
. ${local_file_parent}/common.sh

test_bionic_benchmark(){
    local arch=$1
    if [ "X$arch" != "X32" ] && [ "X$arch" != "X64" ]; then
        echo "The specified $arch is not specified!"
        return
    fi
    local excluded_test=$2
    local cmd="bionic-benchmarks${arch}"
    if [ -n "$(which ${cmd})" ]; then
        for line in $(${cmd} --help 2>&1|grep BM_); do
            if [ -n "$excluded_test" ]; then
                if echo "${excluded_test}"|grep -q ${line}; then
                    output_test_result "${arch}_${line}" "skip"
                    continue
                fi
            fi
            local hasResult=false
            for  res_line in $(${cmd} "^${line}$"|grep "BM_"|tr -s ' '|tr ' ' ','); do
                output_test_result "${arch}_${line}" "pass"
                local key=$(echo $res_line|cut -d, -f1|tr '/' '_')
                local iterations=$(echo $res_line|cut -d, -f2)
                local ns_time=$(echo $res_line|cut -d, -f3)
                local throughput=$(echo $res_line|cut -d, -f4)
                local throughput_units=$(echo $res_line|cut -d, -f5)
                output_test_result "${arch}_${key}_time" "pass" "${ns_time}"  "ns/op"
                if [ -n "${throughput_units}" ];then
                    output_test_result "${arch}_${key}_throught" "pass" "${throughput}" "${throughput_units}"
                fi
                hasResult=true
            done
            if ! $hasResult; then
                output_test_result "${arch}_${line}" "fail"
            fi
        done
    fi
}

test_func(){
    test_bionic_benchmark "64" "BM_property_serial"
    test_bionic_benchmark "32" "BM_property_serial BM_property_read"
}

main(){
    var_test_func="test_func"
    run_test "$@"
}

main "$@"
