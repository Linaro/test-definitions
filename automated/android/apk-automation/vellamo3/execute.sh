#!/bin/bash
# shellcheck disable=SC2034
# Author: Milosz Wasilewski <milosz.wasilewski@linaro.org>

# need to be defined for different benchmark apks
activity="com.quicinc.vellamo/.main.MainActivity"
apk_file_name="com.quicinc.vellamo-3.apk"
test_method="python vc.py"
apk_package="com.quicinc.vellamo"
# following should no need to modify
parent_dir=$(dirname "${0}")
# shellcheck disable=SC1090
source "${parent_dir}/../common/common.sh"
timeout=30m

function func_post_uninstall_vellamo(){
   # shellcheck disable=SC2154
   mv chapterscores.json  "${D_RAWDATA}/chapterscores_${loop_count}.json"
}
post_uninstall="func_post_uninstall_vellamo"
main "$@"
