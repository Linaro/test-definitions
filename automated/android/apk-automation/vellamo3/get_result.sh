#!/bin/bash
# Author: Botao Sun <botao.sun@linaro.org>

function get_result(){
    echo "Test result transfer in progress..."
    if ! adb pull "$1" "$2"; then
        echo "Cached result transfer failed!"
        return 1
    else
        echo "Cached result transfer finished!"
        return 0
    fi
}

get_result "/data/data/com.quicinc.vellamo/files/chapterscores.json" "chapterscores.json"
