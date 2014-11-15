#!/system/bin/sh
#
# piglit shader test.
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

# find and loop over the shader tests found
# recursively in the /data/piglit/shader directory

PIGLIT_PLATFORM=android
export PIGLIT_PLATFORM

bin_path="/system/xbin/piglit/piglit-shader-test/shader_runner"
data_dir="/data/piglit/shader"
glsl_es1_data_dir="${data_dir}/glsl-es-1.00/"
glsl_es3_data_dir="${data_dir}/glsl-es-3.00/"

/system/bin/busybox find ${data_dir} -name *.shader_test | while read file
do
   RESULT=$(${bin_path} ${file} -auto )

   PSTRING='PIGLIT: {"result": "pass"'
   SSTRING='PIGLIT: {"result": "skip"'
   FSTRING='PIGLIT: {"result": "fail"'

   case $RESULT in
     *"$PSTRING"*) echo "${file}: pass";;

     *"$SSTRING"*) echo "${file}: skip";;
  
     *"$FSTRING"*) echo "${file}: fail";;

     *) echo "${file}: fail";;
   esac
done
