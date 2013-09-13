#!/usr/bin/python
import sys
import time
import os

if len(sys.argv) != 2:
    print "usage: infinite_loop.py <secs>"
    sys.exit(0)

t1 = time.time()

while True:
    t2 = time.time() - t1

    if t2 > float(sys.argv[1]):
        exit()
    else:
        os.system("taskset -c 1 calibrator 1000 500M ca.log")
