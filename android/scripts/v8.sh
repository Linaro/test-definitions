#!/system/bin/sh
#
# v8 shell test.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Senthil Kumaran <senthil.kumaran@linaro.org>
# Maintainer: Amit Pundir <amit.pundir@linaro.org>

cd /data/benchmark/v8
if which v8shell 2>/dev/null 1>/dev/null
then v8shell run.js
else d8 run.js
fi

if [ $? -eq 0 ]; then
	echo "v8shell=pass"
else
	echo "v8shell=fail"
fi
