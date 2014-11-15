#!/system/bin/sh
#
# piglit glslparser test.
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

# find and loop over the vert and frag tests found
# looks recursively down the directory tree
PIGLIT_PLATFORM=android
export PIGLIT_PLATFORM
bin_path="/system/xbin/piglit/glslparsertest/glslparsertest"
data_dir="/data/piglit/glslparser/"
/system/bin/busybox find ${data_dir} -name "*.frag" -or -name "*.vert" | while read file
do
   RESULTFOUND=$(grep expect_result ${file} )
   case $RESULTFOUND in
      *fail*) RESULTEXPECTED="fail";;
      *pass*) RESULTEXPECTED="pass";;
      *) RESULTEXPECTED="pass";;
   esac

   check_link=$(grep check_link ${file})
   case "${check_link}" in
      *true*) check_link="--check-link";;
      *) check_link="";;
   esac

   required_version=$(grep 'glsl_version:' ${file})
   case "${check_link}" in
      *3.00*) required_version="3.00";;
      *) required_version="1.00";;
   esac

   RESULT=$(${bin_path} ${check_link} ${file} $RESULTEXPECTED ${required_version})

   PSTRING='PIGLIT: {"result": "pass"'
   SSTRING='PIGLIT: {"result": "skip"'
   FSTRING='PIGLIT: {"result": "fail"'

   case $RESULT in
      *"$PSTRING"*) echo "glslparser ${file}: pass";;
      *"$SSTRING"*) echo "glslparser ${file}: skip";;
      *"$FSTRING"*) echo "glslparser ${file}: fail";;
      *) echo "glslparser ${file}: fail";;
   esac
done
