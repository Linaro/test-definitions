#!/system/bin/sh

loop_times=$1
if [ -z "${loop_times}" ]; then
    loop_times=12
fi
raw_data="/data/local/tmp/bionic-benchmarks-raw.csv"
rm -fr ${raw_data}

add_lava_result_entry(){
    local cmd="lava-test-case"
    if [ -n "$(which $cmd)" ];then
        $cmd "$@"
    else
        echo "$cmd $@"
    fi
}

test_bionic_benchmark(){
    local arch=$1 && shift
    if [ "X$arch" != "X32" ] && [ "X$arch" != "X64" ]; then
        echo "The specified $arch is not specified!"
        return
    fi
    local excluded_test=$1 && shift
    local cmd="bionic-benchmarks${arch}"
    if [ -n "$(which ${cmd})" ]; then
        for line in $(${cmd} --help 2>&1|grep BM_); do
            if [ -n "$excluded_test" ]; then
                if echo "${excluded_test}"|grep -q ${line}; then
                    echo "${arch}_${line} skip"
                    add_lava_result_entry "${arch}_${line}" "--result" "skip"
                    continue
                fi
            fi
            echo "--------------start $line--------"
            local hasResult=false
            for  res_line in $(${cmd} ${line}|grep "BM_"|tr -s ' '|tr ' ' ','); do
                echo "${arch}_$line pass"
                add_lava_result_entry "${arch}_${line}" "--result" "pass"
                local key=$(echo $res_line|cut -d, -f1)
                local iterations=$(echo $res_line|cut -d, -f2)
                local ns_time=$(echo $res_line|cut -d, -f3)
                local throughput=$(echo $res_line|cut -d, -f4)
                local throughput_units=$(echo $res_line|cut -d, -f5)
                echo "${arch}_${key}_time pass $ns_time ns/op"
                add_lava_result_entry "${arch}_${key}_time" "--result" "pass" '--measurement' "${ns_time}"  '--units' "ns/op"
                echo "${arch}_${key}_time,${ns_time}">>${raw_data}
                if [ -n "${throughput_units}" ];then
                    echo "${arch}_${key}_throught pass ${throughput} ${throughput_units}"
                    add_lava_result_entry "${arch}_${key}_throught" "--result" "pass" '--measurement' "${throughput}"  '--units' "${throughput_units}"
                    echo "${arch}_${key}_throught,${throughput}">>${raw_data}
                fi
                hasResult=true
            done
            if ! $hasResult; then
                echo "${arch}_$line fail"
                add_lava_result_entry "${arch}_${line}" "--result" "fail"
            fi
            echo "--------------finished $line--------"
        done
    fi
}

loop_index=0
while [ ${loop_index} -lt ${loop_times} ]; do
    test_bionic_benchmark "64" "BM_property_serial"
    test_bionic_benchmark "32" ""
    loop_index=$((loop_index + 1))
done

attach_cmd="lava-test-run-attach"
if [ -n "$(which ${attach_cmd})" ] && [ -f "${raw_data}" ]; then
    ${attach_cmd} ${raw_data} text/plain
fi
