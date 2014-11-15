#!/bin/sh
#
# Ethernet Test on OpenEmbedded.
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
# Author: Senthil Kumaran <senthil.kumaran@linaro.org>
# Maintainer: Milosz Wasilewski <milosz.wasilewski@linaro.org>, Koen Kooi <koen.kooi@linaro.org>

ifconfig eth0 > ethernet.log
ifconfig eth0 | grep 'inet addr' | awk -F: '{print $2}' | awk '{print $1}'

if [ 0 -eq $? ]
then
    echo "ethernet: pass"
    exit 0
else
    echo "ethernet: fail"
    exit 1
fi
