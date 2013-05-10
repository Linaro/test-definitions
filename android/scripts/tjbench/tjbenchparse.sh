#!/system/bin/sh
#
# tjbenchparse.sh
#
# Copyright (C) 2013, Linaro Limited.
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
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# owner: harigopal.gollamudi@linaro.org
#

while read line
do
 echo $line|sed -n '/RGB/p' >> tmp.txt
done < tjbench.txt

while read inputline
do
 bmp_format="$(echo $inputline | cut -d' ' -f1)"
 jpg_subsamp="$(echo $inputline | cut -d' ' -f3)"
 jpg_qual="$(echo $inputline | cut -d' ' -f4)"

 test_def_comp_perf=$bmp_format'_'$jpg_subsamp'_'$jpg_qual'_comp_perf'$1$2
 test_def_comp_ratio=$bmp_format'_'$jpg_subsamp'_'$jpg_qual'_comp_ratio'$1$2
 test_def_decomp_perf=$bmp_format'_'$jpg_subsamp'_'$jpg_qual'_decomp_perf'$1$2

 comp_perf="$(echo $inputline | cut -d' ' -f7)"
 comp_ratio="$(echo $inputline | cut -d' ' -f8)"
 decomp_perf="$(echo $inputline | cut -d' ' -f9)"
 
 echo $test_def_comp_perf 'pass' $comp_perf 'Mpixels/sec'
 echo $test_def_comp_ratio 'pass' $comp_ratio '%'
 echo $test_def_decomp_perf 'pass' $decomp_perf 'Mpixels/sec'

done < tmp.txt
rm -rf tmp.txt
