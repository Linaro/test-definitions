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

echo "Compile hackbench"
curl 2>/dev/null
if [ $? = 2 ]; then
    DOWNLOAD_FILE="curl -SOk"
else
    DOWNLOAD_FILE="wget --progress=dot -e dotbytes=2M --no-check-certificate"
fi

$DOWNLOAD_FILE http://people.redhat.com/mingo/cfs-scheduler/tools/hackbench.c
gcc -g -Wall -O2 -o hackbench hackbench.c -lpthread
cp hackbench /usr/bin/

echo "Test hackbench on host"
sh ./common/scripts/kvm/test-rt-tests.sh
