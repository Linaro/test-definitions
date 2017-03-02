#!/bin/bash
# shellcheck disable=SC2034

set -e

local_common_file_path="${BASH_SOURCE[0]}"
# shellcheck disable=SC2164
local_common_parent_dir=$(cd "$(dirname "${local_common_file_path}")"; pwd)
# shellcheck disable=SC1090
source "${local_common_parent_dir}/common2.sh"

base_url="http://testdata.validation.linaro.org/apks/"
post_install=""
pre_uninstall=""
ret_value=0
timeout=10m

dir_sys_cpu="/sys/devices/system/cpu/"
f_tmp_governor="/data/local/tmp/governor.txt"

func_setgovernor(){
    local target_governor="$1"
    local target_freq="$2"
    if [ -z "${target_governor}" ]; then
        return
    fi
    for cpu in $(adb shell "ls -d ${dir_sys_cpu}/cpu[0-9]*" |tr '\r' ' '); do
        local dir_cpu_cpufreq="${cpu}/cpufreq"
        adb shell "echo 'echo '${target_governor}' >'${dir_cpu_cpufreq}'/scaling_governor' | su"
        if [ -n "${target_freq}" ]; then
            adb shell "echo 'echo '${target_freq}' >'${dir_cpu_cpufreq}'/scaling_setspeed' | su"
        fi
    done
}

func_cleanup(){
    local target_governor
    target_governor=$(adb shell cat "${f_tmp_governor}")
    func_setgovernor "${target_governor}"
    adb shell rm ${f_tmp_governor}
    func_kill_uninstall "RotationOff.apk" "rotation.off"
}

func_install_start_RotationAPK(){
    local apk_name="RotationOff.apk"
    local apk_path="${D_APKS}/RotationOff.apk"
    if [ -f "${apk_path}" ]; then
        echo "The file(${apk_path}) already exists."
    else
        get_file_with_base_url "${apk_name}" "${BASE_URL}" "${D_APKS}"
    fi
    if ! adb shell pm list packages | grep rotation.off; then
        adb install "${apk_path}"
    fi
    sleep 2
    adb shell am start 'rotation.off/.RotationOff'
    sleep 2
}

function init(){

    func_install_start_RotationAPK

    adb shell "cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor > ${f_tmp_governor}"
    func_setgovernor "performance"
}

func_prepare_benchmark(){
    func_prepare_environment

    init
    echo "init done"
}

func_run_test_bench(){
    # shellcheck disable=SC2154
    local test_script="${D_ROOT}/${loop_app_name}/vc.py"
    local ret
    if [ -f "${test_script}" ]; then
        local test_command="python ${test_script}"
        if [ -n "${var_test_command_timeout}" ]; then
            # shellcheck disable=SC2086
            timeout ${var_test_command_timeout} ${test_command}
            ret=$?
            if [ $ret -eq 124 ]; then
                local tmp_f_name
                tmp_f_name=$(basename "$(mktemp -u -t timeout_screen_XXX.png)")
                adb shell screencap "/data/local/tmp/${tmp_f_name}"
                adb pull "/data/local/tmp/${tmp_f_name}" "${D_SCREENSHOT}/${tmp_f_name}"
                echo  "Time out to run ${test_command}: ${var_test_command_timeout}"
                echo  "You can check ${D_SCREENSHOT}/${tmp_f_name} for reference."
            fi
        else
            ${test_command}
            ret=$?
        fi
        sleep 5
        return $ret
    fi
}

func_post_uninstall_bench(){
    func_post_uninstall
    # shellcheck disable=SC2154
    if [ -n "${post_uninstall}" ]; then
        ${post_uninstall}
    fi
}

function main(){
    echo "test timeout: ${timeout}"
    # shellcheck disable=SC2164
    parent_dir=$(cd "${parent_dir}"; pwd)
    export parent_dir=${parent_dir}

    var_func_parse_parameters=""
    var_func_prepare_environment="func_prepare_benchmark"
    var_func_post_test="func_cleanup"

    var_func_pre_install=""
    var_func_post_install="${post_install}"
    var_func_run_test="func_run_test_bench"
    var_test_command=""
    var_test_command_timeout="${timeout}"
    var_func_pre_uninstall="${pre_uninstall}"
    var_func_post_uninstall="func_post_uninstall_bench"

    # shellcheck disable=SC2154
    G_APPS="${apk_file_name},${activity},$(basename "${parent_dir}")"
    BASE_URL="${base_url}"
    common_main "$@"

    return ${ret_value}
}
