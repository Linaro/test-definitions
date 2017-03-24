#!/system/bin/sh

OUTPUT_FILE="/data/local/tmp/result_unsorted.txt"

test_bionic_benchmark() {
    tbb_arch=$1
    cmd=""
    if [ "X$tbb_arch" = "X32" ]; then
        cmd="/data/benchmarktest/bionic-benchmarks/bionic-benchmarks32"
    elif [ "X$tbb_arch" = "X64" ]; then
        cmd="/data/benchmarktest64/bionic-benchmarks/bionic-benchmarks64"
    else
        echo "The specified arch ($tbb_arch) is not supported!"
        return
    fi
    chmod +x ${cmd} ||:
    if [ -x "${cmd}" ]; then
        for res_line in $(${cmd} |grep "BM_"|tr -s ' '|tr ' ' ','); do
            tbb_key=$(echo "$res_line"|cut -d, -f1|tr '/' '_')
            #tbb_iterations=$(echo "$res_line"|cut -d, -f2)
            tbb_ns_time=$(echo "$res_line"|cut -d, -f3)
            tbb_throughput=$(echo "$res_line"|cut -d, -f4)
            tbb_throughput_units=$(echo "$res_line"|cut -d, -f5)
            echo "${tbb_arch}_${tbb_key}" "pass" >> "${OUTPUT_FILE}"
            echo "${tbb_arch}_${tbb_key}_time" "pass" "${tbb_ns_time}" "ns/op" >> "${OUTPUT_FILE}"
            if [ -n "${tbb_throughput_units}" ]; then
                echo "${tbb_arch}_${tbb_key}_throughput" "pass" "${tbb_throughput}" "${tbb_throughput_units}" >> "${OUTPUT_FILE}"
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
until [ ${i} -gt "${loops}" ]; do
    echo "Run ${i}..."
    test_bionic_benchmark "64"
    test_bionic_benchmark "32"
    i=$((i + 1))
done
