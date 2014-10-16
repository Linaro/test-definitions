#!/system/bin/sh
#
# iozone test
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

# $1 is the testing location. The -b must be specified for parser.
# the file itself does not matter as it is not used.
# The -b cause results reports to be printed to stdout.

#uncomment the following and add cross compiled iozone to this directory.
#mount -o remount,rw /
#iozone_cmd=$1"/iozone -a -i 0 -i 2 -s 16m -V teststring -b iozone_results"

# The original command with a -b gives excel results which are printed to
# stdout and can be parsed

iozone_cmd="iozone -a -i 0 -i 2 -s 16m -V teststring "
${iozone_cmd} > stdout.log 2>&1
sh $PWD/iozoneparser.sh
rm -rf stdout.log
