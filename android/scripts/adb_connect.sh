#!/bin/sh
echo "Checking IP address for $1"
expr "$1" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$'
if [ $? -eq 0 ]
then
    adb connect $1
    IPADDR=$1:5555
fi
