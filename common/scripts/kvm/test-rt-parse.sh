#!/bin/sh
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
# Maintainer: Riku Voipio <riku.voipio@linaro.org>

if [ -f ./common/scripts/min_max_avg_parse.py ]
then
    PARSE_SCRIPT=./common/scripts/min_max_avg_parse.py
elif [-f /root/min_max_avg_parse.py ]
then
    PARSE_SCRIPT=/root/min_max_avg_parse.py
fi

for FILE in *.txt
do
    echo $FILE
    $PARSE_SCRIPT $FILE "Time:" "Seconds"
done
