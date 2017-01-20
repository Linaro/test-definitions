#!/usr/bin/python
import re
import sys
import fileinput


# extract a standard results block from the stream
def standard_results():
    minimum = re.compile("^Min:\s+(?P<min>[\d\.]+)\s+(?P<units>\w+)")
    maximum = re.compile("^Max:\s+(?P<max>[\d\.]+)\s+(?P<units>\w+)")
    average = re.compile("^Avg:\s+(?P<average>[\d\.]+)\s+(?P<units>\w+)")
    standarddev = re.compile("^StdDev:\s+(?P<stddev>[\d\.]+)\s+(?P<units>\w+)")
    finished = 0
    for line in sys.stdin:
        for parser in [maximum, minimum, average, standarddev]:
            result = parser.search(line)
            if result is not None:
                if parser is minimum:
                    test_min = result.group('min')
                    units = result.group('units')
                    print "%s%s_min pass %s %s  " % (test_name, test_args, test_min, units)
                    finished += 1
                    break
                if parser is maximum:
                    test_max = result.group('max')
                    units = result.group('units')
                    finished += 1
                    print "%s%s_max pass %s %s  " % (test_name, test_args, test_max, units)
                    break
                if parser is average:
                    test_avg = result.group('average')
                    units = result.group('units')
                    print "%s%s_avg pass %s %s  " % (test_name, test_args, test_avg, units)
                    finished += 1
                    break
                if parser is standarddev:
                    test_stddev = result.group('stddev')
                    units = result.group('units')
                    print "%s%s_stddev pass %s %s  " % (test_name, test_args, test_stddev, units)
                    finished += 1
                    break
            else:
                continue
        if finished == 4:
            return

    print "ERROR: Parser failed and ran to EOF"
    sys.exit(-1)


def result_results():
    results = re.compile("Result:\s+(?P<result>\w+)")
    finished = 0
    for line in sys.stdin:
        for parser in [results]:
            result = parser.search(line)
            if result is not None:
                if parser is results:
                    test_result = result.group('result')
                    print "%s-%s %s" % (test_name, test_args, test_result)
                    finished += 1
                    break
            else:
                continue
        if finished == 1:
            return

    print "ERROR: Parser failed and ran to EOF"
    sys.exit(-1)


def sched_jitter_results():
    maximum = re.compile("^max jitter:\s+(?P<max>[\d\.]+)\s+(?P<units>\w+)")
    finished = 0
    for line in sys.stdin:
        for parser in [maximum]:
            result = parser.search(line)
            if result is not None:
                if parser is maximum:
                    test_max = result.group('max')
                    units = result.group('units')
                    print "%s%s_max_jitter pass %s  %s" % (test_name, test_args, test_max, units)
                    finished += 1
                    break
            else:
                continue
        if finished == 1:
            # print "min:%s max:%s avg:%s stddev:%s" % (test_min, test_max, test_avg, test_stddev)
            return

    print "ERROR: Parser failed and ran to EOF"
    sys.exit(-1)


def pi_perf_results():
    minimum = re.compile("^Min delay =\s+(?P<min>[\d\.]+)\s+(?P<units>\w+)")
    maximum = re.compile("^Max delay =\s+(?P<max>[\d\.]+)\s+(?P<units>\w+)")
    average = re.compile("^Average delay =\s+(?P<average>[\d\.]+)\s+(?P<units>\w+)")
    standarddev = re.compile("^Standard Deviation =\s+(?P<stddev>[\d\.]+)\s+(?P<units>\w+)")
    finished = 0
    for line in sys.stdin:
        for parser in [maximum, minimum, average, standarddev]:
            result = parser.search(line)
            if result is not None:
                if parser is minimum:
                    test_min = result.group('min')
                    units = result.group('units')
                    print "%s%s_min pass %s %s" % (test_name, test_args, test_min, units)
                    finished += 1
                    break
                if parser is maximum:
                    test_max = result.group('max')
                    units = result.group('units')
                    print "%s%s_max pass %s %s" % (test_name, test_args, test_max, units)
                    finished += 1
                    break
                if parser is average:
                    test_avg = result.group('average')
                    units = result.group('units')
                    print "%s%s_avg pass %s %s" % (test_name, test_args, test_avg, units)
                    finished += 1
                    break
                if parser is standarddev:
                    test_stddev = result.group('stddev')
                    units = result.group('units')
                    print "%s%s_stddev pass %s %s" % (test_name, test_args, test_stddev, units)
                    finished += 1
                    break
            else:
                continue
        if finished == 4:
            return

    print "ERROR: Parser failed and ran to EOF"
    sys.exit(-1)


def do_nothing():
    return


# names of the test parsed out fo the input stream, converted to functioncalls
def async_handler():
    standard_results()
    result_results()


def tc_2():
    result_results()


def gtod_latency():
    standard_results()


def periodic_cpu_load_single():
    standard_results()


def sched_latency():
    standard_results()


def sched_jitter():
    sched_jitter_results()


def sched_football():
    result_results()


def rt_migrate():
    result_results()


def pthread_kill_latency():
    standard_results()
    result_results()


def prio_wake():
    result_results()


def pi_perf():
    pi_perf_results()


def prio_preempt():
    result_results()


def matrix_mult():
    result_results()


def periodic_cpu_load():
    result_results()


def async_handler_jk():
    result_results()

# Parse the input stream and tuen test names into function calls to parse their
# details

test_start = re.compile("--- Running testcase (?P<name>[a-zA-Z0-9_-]+)\s+(?P<args>[a-zA-Z0-9_.\- ]*?)\s*---")
test_finish = re.compile("The .* test appears to have completed.")

for line in sys.stdin:
    for parser in [test_start, test_finish]:
        result = parser.search(line)
        if result is not None:
            if parser is test_start:
                test_name = result.group('name')
                func_name = result.group('name')
                func_name = func_name.replace("-", "_")
                test_args = result.group('args')
                test_args = test_args.replace(" ", "-")
                print
                print "test_start = " + test_name + test_args
                globals()[func_name]()
                break

            if parser is test_finish:
                print "test_finished = " + test_name + test_args
                break
        else:
            continue
