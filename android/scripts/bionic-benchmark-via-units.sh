#!/system/bin/sh

bionic_unit_test64="/data/nativetest64/bionic-unit-tests/bionic-unit-tests64"
bionic_unit_test32="/data/nativetest/bionic-unit-tests/bionic-unit-tests32"


add_lava_result_entry(){
    local test_name=$1 && shift
    local result=$1 && shift
    local measurement=$1 && shift
    local units=$1 && shift

    if [ -z "${test_name}" ] || [ -z "$result" ]; then
        return
    fi
    local output=""
    local lava_paras=""
    if [ -z "${measurement}" ]; then
        output="${test_name}=${result}"
        lava_paras="${test_name} --result ${result}"
    else
        output="${test_name}=${measurement}"
        lava_paras="${test_name} --result ${result} --measurement ${measurement}"
    fi

    if [ -z "$units" ]; then
        units="points"
    fi
    output="${output} ${units}"
    lava_paras="${lava_paras} --units ${units}"

    echo "${output}"

    local cmd="lava-test-case"
    if [ -n "$(which $cmd)" ];then
        $cmd ${lava_paras}
    else
        echo "$cmd ${lava_paras}"
    fi
}

benchmark_via_unit_test(){
    local cmd=$1 && shift
    local arch=$1 && shift
    if [ ! -x "${cmd}" ]; then
        return
    fi

    if [ -n "${arch}" ]; then
        arch="${arch}_"
    fi
    for line in $(${cmd} 2>/dev/null|grep -e OK -e FAILED|grep '('|tr ')(][' ' '|tr -s ' '|sed 's/^ //g'|tr ' ' ','); do
        local result=$(echo $line|cut -d, -f1)
        local test_name=$(echo $line|cut -d, -f2)
        local measurement=$(echo $line|cut -d, -f3)
        local units=$(echo $line|cut -d, -f4)

        if [ "X${result}" = "XOK" ]; then
            result="pass"
        else
            result="fail"
        fi
        add_lava_result_entry "${arch}${test_name}" "${result}" "${measurement}" "${units}"
    done
}

benchmark_via_unit_test "${bionic_unit_test64}" "64"
benchmark_via_unit_test "${bionic_unit_test32}" "32"
