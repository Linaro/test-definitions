#!/bin/bash
#
# Basic Graphics test cases
#
# Copyright (C) 2012, Linaro Limited.
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
#

DEFAULT_USER="linaro"

source include/sh-test-lib

set_lightdm_session() {
    session=$1

    # make sure no other config file is bypassing us
    rm -f /home/$DEFAULT_USER/.dmrc
    rm -rf /var/cache/lightdm
    rm -rf /var/lib/AccountsService/users
    dbus_user_path=`dbus-send --system --type=method_call --print-reply \
        --dest=org.freedesktop.Accounts /org/freedesktop/Accounts \
        org.freedesktop.Accounts.FindUserByName string:$DEFAULT_USER \
        | awk -F "\"" {'print $2'}`
    dbus-send --system --type=method_call --print-reply \
        --dest=org.freedesktop.Accounts ${dbus_user_path} \
        org.freedesktop.Accounts.User.SetXSession string:$session 1>&2
}

kill_xorg() {
    pid=`pidof /usr/bin/X`
    if [ "x$pid" != "x" ]; then
        kill -9 $pid 1>&2
    fi
    rm -f /tmp/.X0-lock
}

test_restore() {
    kill_xorg
    service lightdm stop 1>&2
    sleep 2
    service lightdm start 1>&2
    sleep 10 # give enough time to start
}

## Test case definitions

# Validate that Xorg is running
test_xorg() {
    TEST="xorg_running"
    if ! service lightdm status | grep -q "start\/running"; then
        service lightdm start 1>&2
        check_return_fail "lightdm start" && return 1
        sleep 10 # give enough time to start and possibly fail
    fi

    pidof "/usr/bin/X" 1>&2
    check_return_fail "Xorg not running" && return 1

    pass_test
}

# Validate that the board can run unity-2d
test_unity2d() {
    TEST="unity_2d_running"

    service lightdm stop 1>&2
    sleep 2 # to die in peace
    set_lightdm_session ubuntu-2d
    service lightdm start 1>&2
    check_return_fail "lightdm start" && return 1

    sleep 120
    pidof "/usr/bin/unity-2d-panel" 1>&2
    check_return_fail "unity-2d-panel not running" && return 1
    pidof "/usr/bin/unity-2d-shell" 1>&2
    check_return_fail "unity-2d-shell not running" && return 1

    pass_test
}

# Validate that the board can run unity-3d
test_unity3d() {
    TEST="unity_3d_running"

    service lightdm stop 1>&2
    sleep 2 # to die in peace
    set_lightdm_session ubuntu
    service lightdm start 1>&2
    check_return_fail "lightdm start" && return 1

    sleep 180
    pidof "/usr/bin/compiz" 1>&2
    check_return_fail "compiz not running" && return 1
    pidof "/usr/bin/gtk-window-decorator" 1>&2
    check_return_fail "gtk-window-decorator not running" && return 1
    pidof "/usr/lib/unity/unity-panel-service" 1>&2
    check_return_fail "unity-panel-service not running" && return 1

    pass_test
}

# Validate that the board is able to start unity 3d
test_unity_support() {
    TEST="nux_tools_unity_support"

    service lightdm stop 1>&2
    kill_xorg
    sleep 2 # to die in peace
    (/usr/bin/X -verbose 10 :0 1>&2 &)
    export DISPLAY=:0.0
    check_return_fail "Xorg failed to start" && return 1

    sleep 5
    /usr/lib/nux/unity_support_test 1>&2
    check_return_fail "unity 3d is not supported" && return 1

    pass_test
}

# Validate that the board has a valid gles driver
test_opengles_driver() {
    TEST="valid_not_mesa_opengles_driver"

    service lightdm stop 1>&2
    kill_xorg
    sleep 2 # to die in peace
    (/usr/bin/X -verbose 10 :0 1>&2 &)
    export DISPLAY=:0.0
    check_return_fail "Xorg failed to start" && return 1
    sleep 5

    /usr/bin/es2_info 1>&2

    if /usr/bin/es2_info 2>&1 | grep -q "EGL_VENDOR = Mesa"; then
        fail_test "EGL driver provided by Mesa"
        return 1
    fi

    pass_test
}

# check we're root
if ! check_root; then
    error_msg "Please run the test case as root"
fi

# run the tests
test_xorg
test_unity2d
test_unity3d
test_unity_support
test_opengles_driver

# get lightdm running again for later usage
test_restore
