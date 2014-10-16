#!/system/bin/sh
#
# iozoneparser
#
# Copyright (C) 2010 - 2014, Linaro Limited.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Harigopal Gollamudi <harigopal.gollamudi@linaro.org>
# Maintainer: Botao Sun <botao.sun@linaro.org>

grep -A 13 "KB  reclen   write rewrite"  stdout.log | sed '1d' > temp.log

while read line
do
    var="$(echo $line | cut -d' ' -f2)"

    Write_val="$(echo $line | cut -d' ' -f3)"
    ReWrite_val="$(echo $line | cut -d' ' -f4)"
    RandomRead_val="$(echo $line | cut -d' ' -f5)"
    RandomWrite_val="$(echo $line | cut -d' ' -f6)"

    Write_string='iozone_Write_KB_16384_rclen'_$var' '$Write_val' 'Kbytes/sec' 'pass
    RandomRead_string='iozone_Random_read_KB_16384_rclen'_$var' '$RandomRead_val' 'Kbytes/sec' 'pass
    RandomWrite_string='iozone_Random_write_KB_16384_rclen'_$var' '$RandomWrite_val' 'Kbytes/sec' 'pass
    ReWrite_string='iozone_Rewrite_KB_16384_rclen'_$var' '$ReWrite_val' 'Kbytes/sec' 'pass

    echo $Write_string
    echo $RandomRead_string
    echo $RandomWrite_string
    echo $ReWrite_string

done < temp.log

rm -rf temp.log
