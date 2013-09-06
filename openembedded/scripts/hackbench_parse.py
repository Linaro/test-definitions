#!/usr/bin/python

import re
import sys
from numpy import *

values = []

r = re.compile("Time:\s(?P<measurement>\d+\.\d*)")
f = open(sys.argv[1], "r")
for line in f.readlines():
    search = r.search(line)
    if search: 
       values.append(float(search.group('measurement')))

# Usually the first value is inexplicably high
values.pop(0)

np_array = array(values)

format = "%-16s%-16s%-16s%-16s"
print format % ("hackbench_min:", str(min(np_array)),    "seconds", "pass")
print format % ("hakcbench_max:", str(max(np_array)),    "seconds", "pass")
print format % ("hackbench_avg:", str(mean(np_array)),   "seconds", "pass")
print format % ("hackbench_mdn:", str(median(np_array)), "seconds", "pass")
