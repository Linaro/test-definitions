#!/system/bin/sh
#
# piglit gles3.0 test.
#
# Copyright (C) 2014, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51   Franklin Street, Fifth Floor, Boston, MA  02110-1301,
# USA.
#
# owner: yongqin.liu@linaro.org
#
###############################################################################

PIGLIT_PLATFORM=android
export PIGLIT_PLATFORM

PSTRING='PIGLIT: {"result": "pass"'
SSTRING='PIGLIT: {"result": "skip"'
FSTRING='PIGLIT: {"result": "fail"'

gles3_bin_dir=/system/xbin/piglit/piglit-spec-gles3

normal_test(){
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

test_oes_compressed_etc2_texture_miptree_gles3(){
    PIGLIT_SOURCE_DIR="/data/piglit"
    export PIGLIT_SOURCE_DIR
    cmd="${gles3_bin_dir}/oes_compressed_etc2_texture-miptree_gles3"
    test_base_name="oes_compressed_etc2_texture-miptree_gles3"
    formats="rgb8 srgb8 rgba8 srgb8-alpha8 r11 rg11 rgb8-punchthrough-alpha1 srgb8-punchthrough-alpha1"
    for format in ${formats}; do
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
