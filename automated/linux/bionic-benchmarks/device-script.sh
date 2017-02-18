#!/system/bin/sh

local_file_path="$0"
local_file_parent=$(cd $(dirname ${local_file_path}); pwd)

OUTPUT_FILE="/data/local/tmp/result_unsorted.txt"
test_bionic_benchmark() {
    local arch=$1
    local cmd=""
    if [ "X$arch" = "X32" ]; then
        cmd="/system/bin/bionic-benchmarks32"
    elif [ "X$arch" = "X64" ]; then
        cmd="/system/bin/bionic-benchmarks64"
    else
        echo "The specified arch ($arch) is not supported!"
        return
    fi
    chmod +x ${cmd} ||:
    if [ -x "${cmd}" ]; then
        for res_line in $(${cmd} |grep "BM_"|tr -s ' '|tr ' ' ','); do
            local key=$(echo $res_line|cut -d, -f1|tr '/' '_')
            local iterations=$(echo $res_line|cut -d, -f2)
            local ns_time=$(echo $res_line|cut -d, -f3)
            local throughput=$(echo $res_line|cut -d, -f4)
            local throughput_units=$(echo $res_line|cut -d, -f5)
            echo "${arch}_${key}" "pass" >> "${OUTPUT_FILE}"
            echo "${arch}_${key}_time" "pass" "${ns_time}" "ns/op" >> "${OUTPUT_FILE}"
            if [ -n "${throughput_units}" ]; then
                echo "${arch}_${key}_throughput" "pass" "${throughput}" "${throughput_units}" >> "${OUTPUT_FILE}"
            fi
        done
    else
        echo "Can't execute ${cmd}!"
        return
    fi
}

: > "${OUTPUT_FILE}"
loops=1
[ $# -gt 0 ] && loops=$1
i=1
until [ ${i} -gt ${loops} ]; do
    echo "Run ${i}..."
    test_bionic_benchmark "64"
    test_bionic_benchmark "32"
    i=$(($i + 1))
done
