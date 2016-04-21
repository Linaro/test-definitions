#!/bin/sh
#
# Blogbench is a portable filesystem benchmark.
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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Chase Qi <chase.qi@linaro.org>

iteration=$1
partition=$2

# Set the directory for blogbench test.
if [ -n "$partition" ]; then
    if [ -z "$(mount | grep $partition)" ]; then
        mount $partition /mnt
        cd /mnt/
    else
        mount_point=$(mount | grep $partition | awk '{print $3}')
        cd $mount_point
    fi
fi
mkdir ./bench

# Run blogbench test.
blogbench --iteration=$iteration -d ./bench 2>&1 | tee blogbench.txt
if [ $? -eq 0 ]; then
    lava-test-case blogbench-run --result pass
else
    lava-test-case blogbench-run --result fail
fi

# Parse test result.
for test in writes reads
do
    score=$(grep "Final score for $test" blogbench.txt | awk '{print $NF}')
    if [ -n "$score" ]; then
        lava-test-case blogbench-$test --result pass --measurement $score --units none
    else
        lava-test-case blogbench-$test --result fail --measurement $score --units none
    fi
done

rm -rf ./bench
