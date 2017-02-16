#!/bin/sh -e

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

bandwidth_test() {
    test_list="rd wr rdwr cp frd fwr fcp bzero bcopy"
    for test in ${test_list}; do
        # bw_mem use MB/s as units.
        # shellcheck disable=SC2154
        ./bin/"${abi}"/bw_mem 512m "$test" 2>&1 \
          | awk -v test_case="memory-${test}-bandwidth" \
            '{printf("%s pass %s MB/s\n", test_case, $2)}' \
          | tee -a "${RESULT_FILE}"
    done
}

latency_test() {
    # Set memory size to 256M to make sure that main memory will be measured.
    lat_output="${OUTPUT}/lat-mem-rd.txt"
    ./bin/"${abi}"/lat_mem_rd 256m 128 2>&1 | tee "${lat_output}"

    # According to lmbench manual:
    # Only data accesses are measured; the instruction cache is not measured.
    # L1: Try stride of 128 and array size of .00098.
    # L2: Try stride of 128 and array size of .125.
    grep "^0.00098" "${lat_output}" \
      | awk '{printf("l1-read-latency pass %s ns\n", $2)}' \
      | tee -a "${RESULT_FILE}"

    grep "^0.125" "${lat_output}" \
      | awk '{printf("l2-read-latency pass %s ns\n", $2)}' \
      | tee -a "${RESULT_FILE}"

    # Main memory: the last line.
    grep "^256" "${lat_output}" \
      | awk '{printf("main-memory-read-latency pass %s ns\n", $2)}' \
      | tee -a "${RESULT_FILE}"
}

# Test run.
create_out_dir "${OUTPUT}"

detect_abi
bandwidth_test
latency_test
