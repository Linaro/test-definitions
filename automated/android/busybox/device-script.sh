#!/system/bin/sh
# Busybox smoke tests.

OUTPUT="/data/local/tmp/busybox/"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

rm -rf "${OUTPUT}"
mkdir -p "${OUTPUT}"
cd "${OUTPUT}" || exit

check_return() {
    exit_code="$?"
    test_case="$1"
    if [ "${exit_code}" -ne 0 ]; then
        echo "${test_case} fail" | tee -a "${RESULT_FILE}"
    else
        echo "${test_case} pass" | tee -a "${RESULT_FILE}"
    fi
}

if ! which busybox; then
    echo "busybox-existence-check fail" | tee -a "${RESULT_FILE}"
    exit 0
fi

busybox mkdir dir
check_return "mkdir"

busybox touch dir/file.txt
check_return "touch"

busybox ls dir/file.txt
check_return "ls"

busybox cp dir/file.txt dir/file.txt.bak
check_return "cp"

busybox rm dir/file.txt.bak
check_return "rm"

busybox echo 'busybox test' > dir/file.txt
check_return "echo"

busybox cat dir/file.txt
check_return "cat"

busybox grep 'busybox' dir/file.txt
check_return "grep"

# shellcheck disable=SC2016
busybox awk '{printf("%s: awk\n", $0)}' dir/file.txt
check_return "awk"

busybox free
check_return "free"
