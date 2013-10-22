#!/usr/bin/python
import re
import sys
import os

#parse format:
#nfs04       1  TPASS  :  Test Successful
parser = re.compile("^(?P<test_case_name>\\S+)\\s+\\d+\\s+(?P<result>\\w+)\\s+:\\s+(?P<test_case_info>.+)")
data = sys.stdin.readlines()

for line in data:
    result = parser.search(line)
    if result is not None:
        print "test_case_id:" + result.group('test_case_name') + ": " + result.group('test_case_info') + " result:" + result.group('result')
