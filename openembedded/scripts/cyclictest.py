#!/usr/bin/python
import re
import sys
import os

# threshold values, in us
max_threshold = 15000
avg_threshold = 20
min_threshold = 10
pass_max_threshold = True
pass_avg_threshold = True
pass_min_threshold = True
max_lentency = 0
avg_lentency = 0
min_lentency = 0

#parse format:
# T:49 ( 4518) P:31 I:4243600 C:      2 Min:      8 Act:    8 Avg:    8 Max:       9
parser = re.compile("(?P<T>\d+)\D+(?P<T1>\d+)\D+(?P<P>\d+)\D+(?P<I>\d+)\D+(?P<C>\d+)\D+(?P<Min>\d+)\D+(?P<Act>\d+)\D+(?P<Avg>\d+)\D+(?P<Max>\d+)")

data = sys.stdin.readlines()

if len(data) == 0:
    print "test_case_id:Test program running result:fail measurement:0 units:none"
else:
    for line in data:
        result = parser.search(line)
        if result is not None:
            if int(result.group('Max')) > max_threshold:
                pass_max_threshold = False

            if int(result.group('Avg')) > avg_threshold:
                pass_avg_threshold = False

            if int(result.group('Min')) > min_threshold:
                pass_min_threshold = False

            if int(result.group('Max')) > max_lentency:
                max_lentency = int(result.group('Max'))

            if int(result.group('Avg')) > avg_lentency:
                avg_lentency = int(result.group('Avg'))

            if int(result.group('Min')) > min_lentency:
                min_lentency = int(result.group('Min'))

    if pass_max_threshold is True:
        print "test_case_id:Max latency bound (<15000us) result:pass measurement:" + str(max_lentency) + " units:usecs"
    else:
        print "test_case_id:Max latency bound (<15000us) result:fail measurement:" + str(max_lentency) + " units:usecs"

    if pass_avg_threshold is True:
        print "test_case_id:Avg latency bound (<20us) result:pass measurement:" + str(avg_lentency) + " units:usecs"
    else:
        print "test_case_id:Avg latency bound (<20us) result:fail measurement:" + str(avg_lentency) + " units:usecs"

    if pass_min_threshold is True:
        print "test_case_id:Min latency bound (<10us) result:pass measurement:" + str(min_lentency) + " units:usecs"
    else:
        print "test_case_id:Min latency bound (<10us) result:fail measurement:" + str(min_lentency) + " units:usecs"
