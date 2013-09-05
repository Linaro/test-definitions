#!/usr/bin/python
import sys
import time
import os

t1 = time.time()

while True:
    t2 = time.time() - t1

    if t2 > float(sys.argv[1]):
        exit()
    else:
        os.system("calibrator 1000 500M ca.log")
