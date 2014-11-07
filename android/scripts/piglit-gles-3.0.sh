#!/system/bin/sh

export PIGLIT_PLATFORM=android

PSTRING='PIGLIT: {"result": "pass"'
SSTRING='PIGLIT: {"result": "skip"'
FSTRING='PIGLIT: {"result": "fail"'

gles3_bin_dir=/system/xbin/piglit/piglit-spec-gles3

function normal_test(){
    cmd="${gles3_bin_dir}/$1"
    test_name="${1}"
    RESULT=$(${cmd} -auto)
    case $RESULT in
        *"$PSTRING"*) echo "${test_name}: pass";;
        *"$SSTRING"*) echo "${test_name}: skip";;
        *"$FSTRING"*) echo "${test_name}: fail";;
        *) echo "${test_name}: fail";;
    esac
}

function test_oes_compressed_etc2_texture_miptree_gles3(){
    cmd="${gles3_bin_dir}/oes_compressed_etc2_texture-miptree_gles3"
    test_base_name="oes_compressed_etc2_texture-miptree_gles3"
    formats="rgb8 srgb8 rgba8 srgb8-alpha8 r11 rg11 rgb8-punchthrough-alpha1 srgb8-punchthrough-alpha1"
    for format in ${formats}; do
        export PIGLIT_SOURCE_DIR="/data/piglit"
        RESULT=$(${cmd} ${format} -auto)

        test_name="${test_base_name}_${format}"
        case $RESULT in
            *"$PSTRING"*) echo "${test_name}: pass";;
            *"$SSTRING"*) echo "${test_name}: skip";;
            *"$FSTRING"*) echo "${test_name}: fail";;
            *) echo "${test_name}: fail";;
        esac

    done

}
normal_test "drawarrays-vertexid_gles3"
normal_test "minmax_gles3"
normal_test "texture-immutable-levels_gles3"
test_oes_compressed_etc2_texture_miptree_gles3
