#!/system/bin/sh
#
# piglit gles2.0 test.
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

gles2_bin_dir="/vendor/bin/"

normal_test(){
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
