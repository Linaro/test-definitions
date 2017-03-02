# Author: Botao Sun <botao.sun@linaro.org>
import os
import sys
import time
from subprocess import call
from com.dtmilano.android.viewclient import ViewClient, ViewNotFoundException

curdir = os.path.realpath(os.path.dirname(__file__))
f_output_result = "%s/../common/output-test-result.sh" % curdir


def dump_always():
    success = False
    while not success:
        try:
            vc.dump()
            success = True
        except RuntimeError:
            print("Got RuntimeError when call vc.dump()")
            time.sleep(5)
        except ValueError:
            print("Got ValueError when call vc.dump()")
            time.sleep(5)


def collect_score(testcase, run_result):
    call([f_output_result, "geekbench3_" + testcase, run_result])


def collect_score_with_measurement(testcase, run_result, score_number, score_unit):
    call([f_output_result, "geekbench3_" + testcase, run_result, str(score_number), score_unit])


def all_fail():
    print("%s FAILED!" % testcase_run)
    collect_score(testcase_run, "fail")
    collect_score(testcase_singlecore, "skip")
    collect_score(testcase_multicore, "skip")

raw_output_file = "%s/../rawdata/geekbench3_result.gb3" % curdir
singlecore_keyword = "score"
singlecore_result = {}
multicore_keyword = "multicore_score"
multicore_result = {}
endpoint_keyword = "multicore_rate"
package_name = "com.primatelabs.geekbench3"

# Test cases
testcase_run = "geekbench_run"
testcase_singlecore = "geekbench_single_core"
testcase_multicore = "geekbench_multi_core"

device, serialno = ViewClient.connectToDeviceOrExit()
kwargs2 = {'startviewserver': True, 'forceviewserveruse': False, 'autodump': False, 'ignoreuiautomatorkilled': True, 'compresseddump': False}
vc = ViewClient(device, serialno, **kwargs2)

try:
    time.sleep(2)
    dump_always()
    trigger = vc.findViewByIdOrRaise(package_name + ":id/runBenchmarks")
    trigger.touch()
    print("Geekbench 3 Test Started!")
except ViewNotFoundException:
    run_result = "fail"
    print("Can not find the start button! Please check the screen!")
    all_fail()
    sys.exit(1)

time.sleep(10)
dump_always()

try:
    vc.findViewByIdOrRaise("android:id/progress")
except ViewNotFoundException:
    run_result = "fail"
    print("Something goes wrong! It is unusual that the test has not been started after 10+ seconds! Please manually check it!")
    all_fail()
    sys.exit(1)

finished = False
while (not finished):
    time.sleep(45)
    dump_always()
    flag = vc.findViewWithText("RESULT")
    if flag is not None:
        print("Geekbench 3 Test Finished!")
        finished = True
    else:
        print("Geekbench 3 Test is still in progress...")

# Generate the .gb3 file
device.press('KEYCODE_MENU')
time.sleep(1)
dump_always()
share_button = vc.findViewWithText("Share")
if share_button is not None:
    share_button.touch()
    time.sleep(5)
else:
    print("Can not find the Share button to generate .gb3 file! Please check the screen!")
    sys.exit(1)

# Get and parse the result file
call(['%s/get_result.sh' % curdir])
if os.path.exists(raw_output_file) is True:
    logfile = open(raw_output_file, "r")
    for line in logfile:
        # Can't believe this is an one line file!
        # Fine the ending point with the information we want
        endpoint = line.find(endpoint_keyword)
        if endpoint == -1:
            print("Can not find %s in log file! Please manually check it!" % endpoint_keyword)
            all_fail()
            sys.exit(1)
        else:
            print("%s PASSED!" % testcase_run)
            collect_score(testcase_run, "pass")
            result_cut = line[0:endpoint].split(",")
            result_cut = [element.replace('"', '').replace(' ', '') for element in result_cut]
            for item in result_cut:
                if singlecore_keyword == item.split(":")[0]:
                    singlecore_result[singlecore_keyword] = item.split(":")[1]
                if multicore_keyword == item.split(":")[0]:
                    multicore_result[multicore_keyword] = item.split(":")[1]
            if len(singlecore_result) != 1:
                run_result = "fail"
                print("Incorrect value for single core test result! Please check the test result file!")
                print("%s Test FAILED!" % testcase_singlecore)
                collect_score(testcase_singlecore, run_result)
            else:
                run_result = "pass"
                print("%s Test PASSED! The Score Number is %s" % (testcase_singlecore, str(singlecore_result[singlecore_keyword])))
                collect_score_with_measurement(testcase_singlecore, run_result, singlecore_result[singlecore_keyword], "No-Unit")
            if len(multicore_result) != 1:
                run_result = "fail"
                print("Incorrect value for multi core test result! Please check the test result file!")
                print("%s Test FAILED!" % testcase_multicore)
                collect_score(testcase_multicore, run_result)
            else:
                run_result = "pass"
                print("%s Test PASSED! The Score Number is %s" % (testcase_multicore, str(multicore_result[multicore_keyword])))
                collect_score_with_measurement(testcase_multicore, run_result, multicore_result[multicore_keyword], "No-Unit")

    logfile.close()
else:
    print("Result file does not exist: %s" % raw_output_file)
    sys.exit(1)

# Back to main screen, gracefully
for i in range(0, 6):
    device.press('KEYCODE_BACK')
    time.sleep(2)

# Renamed the test result file to processed
os.unlink(raw_output_file)
