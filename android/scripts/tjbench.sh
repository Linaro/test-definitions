#!/system/bin/sh

local_file_path="$0"
local_file_parent=$(cd $(dirname ${local_file_path}); pwd)
. ${local_file_parent}/common.sh

img_dir="/data/local/tmp"
#imgs="vgl_5674_0098.ppm  vgl_6434_0018.ppm  vgl_6548_0026.ppm artificial.ppm nightshot_iso_100.ppm"
imgs="nightshot_iso_100.ppm"

func_tjbench(){
    cmd=$1
    if [ -z "${cmd}" ];then
        return
    else
        shift
    fi
    if [ -z "$(which $cmd)" ];then
        return
    fi

    for img in ${imgs}; do
        for line in $($cmd ${img_dir}/${img} 95 -rgb -quiet $@|grep '^RGB'|tr -s ' '|tr ' ' ','); do
            key=$(echo $line|cut -d, -f1-6)
            compPerf=$(echo $line|cut -d, -f7)
            compRatio=$(echo $line|cut -d, -f8)
            decompPerf=$(echo $line|cut -d, -f9)
            key="${cmd}_${key}_${img}_95_rgb"
            if [ -n "$*" ]; then
                key="${key}_$*"
            fi
            key=$(echo $key|tr ', ' '_'|tr -d ':()/')

            output_test_result "${key}_CompPerf" "pass" "${compPerf}"  "Mpixels/sec"
            output_test_result "${key}_CompRatio" "pass" "${compRatio}"  "%"
            output_test_result "${key}_DecompPerf" "pass" "${decompPerf}"  "Mpixels/sec"
        done
    done
}

test_func(){
    if which tj32 >/dev/null; then
        cmdname="tj"
    else
        cmdname="tjbench"
    fi
    func_tjbench ${cmdname}64 scale 1/2
    func_tjbench ${cmdname}64
    func_tjbench ${cmdname}32 scale 1/2
    func_tjbench ${cmdname}32
}

main(){
    cd $img_dir
    for img in ${imgs}; do
        wget http://testdata.validation.linaro.org/tjbench/${img} -O ${img_dir}/${img}
    done

    var_test_func="test_func"
    run_test "$@"
}

main "$@"
