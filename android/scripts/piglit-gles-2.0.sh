#!/system/bin/sh

export PIGLIT_PLATFORM=android

gles2_bin_dir="/system/xbin/piglit/piglit-spec-gles2"

function normal_test(){
    cmd="${gles2_bin_dir}/$1"
    test_name="${1}"
    RESULT=$(${cmd} -auto)
    case $RESULT in
        *"$PSTRING"*) echo "${test_name}: pass";;
        *"$SSTRING"*) echo "${test_name}: skip";;
        *"$FSTRING"*) echo "${test_name}: fail";;
        *) echo "${test_name}: fail";;
    esac
}

normal_test "glsl-fs-pointcoord_gles2"
normal_test "minmax_gles2"
normal_test "multiple-shader-objects_gles2"
