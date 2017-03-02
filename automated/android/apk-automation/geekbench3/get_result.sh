#!/bin/bash
# Author: Botao Sun <botao.sun@linaro.org>

parent_dir=$(dirname "$0")
# shellcheck disable=SC1090
source "${parent_dir}/../common/common.sh"

OUT_DIR="${D_RAWDATA}/files-$(date +%Y%m%H%M%S)"

function get_result(){
    echo "Geekbench test result transfer in progress..."
    local target_dir=$1
    local local_dir=$2
    if ! adb pull "${target_dir}" "${local_dir}"; then
        echo "Test result transfer failed!"
        return 1
    else
        echo "Test result transfer finished!"
        # Rename the file, should be only one .gb3 file on target directory
        rm -fr "${local_dir}/../geekbench3_result.gb3"
        if ! mv "${local_dir}"/*.gb3 "${local_dir}/../geekbench3_result.gb3"; then
            echo "File rename failed! There should be only one .gb3 file under the current directory!"
            return 1
        else
            echo "Test result file for Geekbench 3 now is geekbench3_result.gb3"
            return 0
        fi
    fi
}

get_result "/data/user/0/com.primatelabs.geekbench3/files" "${OUT_DIR}"
