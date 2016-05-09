#! /bin/sh

server_ip=$1
request_rate=$2

httperf --server $server_ip --port 80 --uri /index.html --rate $request_rate --num-conn 50000 --send-buffer=128 --recv-buffer=16384 --num-call 1 --timeout 1 --hog 2>/dev/null > httperf_output
connection_rate=$(grep "Connection rate:" httperf_output | cut -d " " -f 3)
echo "test_case_id:connection-rate measurement:$connection_rate units:conn/s result:pass"

