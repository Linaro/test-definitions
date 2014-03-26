#!/bin/bash
#
# Device Tree test cases for Linux Linaro ubuntu
#
# Copyright (C) 2012 - 2014, Linaro Limited.
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
# Author: Ricardo Salveti <rsalveti@linaro.org>
# Maintainer Botao Sun <botao.sun@linaro.org>
#

source include/sh-test-lib

## Test case definitions

# Check if /proc/device-tree is available
test_has_proc_device_tree() {
    TEST="has_proc_device_tree"

    if [ ! -d /proc/device-tree ]; then
        fail_test "Unable to find /proc/device-tree"
        return 1
    fi

    find /proc/device-tree

    pass_test
}

# Check if model is not empty
test_device_tree_model_not_empty() {
    TEST="device_tree_model_not_empty"

    if [ ! -f /proc/device-tree/model ]; then
        fail_test "Unable to find /proc/device-tree/model"
        return 1
    fi

    model=`cat /proc/device-tree/model`
    if [ -z "$model" ]; then
        fail_test "Empty model description at /proc/device-tree/model"
        return 1
    fi

    echo "The model of the board is $model"

    pass_test
}

# run the tests
test_has_proc_device_tree
test_device_tree_model_not_empty

# clean exit so lava-test can trust the results
exit 0