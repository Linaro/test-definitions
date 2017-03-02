#!/bin/bash
# shellcheck disable=SC2034
# shellcheck disable=SC2181

#need to be defined for different benchmark apks
activity="com.antutu.ABenchMark/.ABenchMarkStart"
apk_file_name="AnTuTu6.0.4.apk"
test_method="python vc.py"
apk_package="com.antutu.ABenchMark"
apk_3d_name="antutu_benchmark_v6_3d_f1.apk"
apk_3d_pkg="com.antutu.benchmark.full"

function install_3d_benchmark(){
    get_file_with_base_url "${apk_3d_name}" "${BASE_URL}" "${D_APKS}"
    if [ $? -ne 0 ];then
        echo "Failed to get the Apk file of ${apk_3d_name}"
        exit 1
    fi
    adb install -r "${D_APKS}/${apk_3d_name}"
    if [ $? -ne 0 ]; then
        # shellcheck disable=SC2154
        echo "Failed to install ${loop_app_apk}."
        exit 1
     fi
}

function uninstall_3d_benchmark(){
    pkg_3d="com.antutu.benchmark.full"
    func_kill_uninstall "${apk_3d_name}" "${apk_3d_pkg}"
}

#following should no need to modify
parent_dir=$(dirname "$0")
# shellcheck disable=SC1090
source "${parent_dir}/../common/common.sh"
post_install="install_3d_benchmark"
post_uninstall="uninstall_3d_benchmark"
timeout=30m
main "$@"
