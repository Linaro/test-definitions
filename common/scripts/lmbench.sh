#!/bin/sh

echo "BEGIN LMBENCH"
for i in $(seq 1 1000)
do
    echo "lat_ctx iteration number $i "
    /usr/bin/lat_ctx  -s 64 2
    /usr/bin/lat_ctx  -s 64 8
    /usr/bin/lat_ctx  -s 64 16
    /usr/bin/lat_ctx  -s 64 20
done
echo "END LMBENCH"
