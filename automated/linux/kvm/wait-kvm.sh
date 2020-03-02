#!/bin/sh -e

[ -r "$1" ]||exit 0

# shellcheck disable=SC2086
while [ -d "/proc/$(cat $1)/" ]
do
    sleep 10
done
