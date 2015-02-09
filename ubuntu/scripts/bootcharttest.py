#!/usr/bin/env python

import sys
from pybootchartgui import main
from pybootchartgui import parsing

if __name__ == '__main__':
    argv = sys.argv[1:]
    parser = main._mk_options_parser()
    options, args = parser.parse_args(argv)
    writer = main._mk_writer(options)
    res = parsing.parse(writer, args, options.prune, options.crop_after, options.annotate)
    duration = float(res[3].duration) / 100
    print res[0]['title']
    print "uname:", res[0]['system.uname']
    print "release:", res[0]['system.release']
    print "CPU:", res[0]['system.cpu']
    print "kernel options:", res[0]['system.kernel.options']
    print "time:", duration
