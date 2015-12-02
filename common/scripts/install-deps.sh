#!/bin/bash

# Example:
# ./install-deps.sh android-tools-adb android-tools-fastboot
# Wait for unlock apt function waits for the apt-get process to be completed
# If in case it is already running

wait_for_unlock_apt () {
    RET=1
    while [ $RET -eq 1 ]; do
        PID=`pgrep apt-get`
        if [ -z $PID ]; then
            RET=0
            break
        fi
        echo "apt-get still running PID: $PID"
        sleep 5
    done
}

# Read each package name from command line arguments
for pkg in ${@}
do
    # Check if packages are already installed
    STATUS=`dpkg-query -W -f='${Status} \n' $pkg | awk '{print $1}'`

    if [ "$STATUS" == "install" ]; then
        echo "==== $pkg package is already installed ===="
    else
        wait_for_unlock_apt
        echo "==== Install $pkg package ===="
        apt-get install -y $pkg
    fi
done
exit 0
