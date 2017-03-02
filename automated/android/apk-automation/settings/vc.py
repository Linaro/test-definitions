# Author: Botao Sun <botao.sun@linaro.org>
import sys
import time
from subprocess import call
from com.dtmilano.android.viewclient import ViewClient, ViewNotFoundException

# Check points
title_check = "Settings"
network_check = "WIRELESS & NETWORKS"
device_check = "DEVICE"
personal_check = "PERSONAL"
accounts_check = "Accounts"
system_check = "SYSTEM"

item_list = [network_check, device_check, personal_check, accounts_check, system_check]
checked_item = []
missing_item = []
positive_counter = 0


def collect_score(testcase, run_result):
    call(['lava-test-case', testcase, '--result', run_result])

device, serialno = ViewClient.connectToDeviceOrExit()

kwargs2 = {'startviewserver': True, 'forceviewserveruse': False, 'autodump': False, 'ignoreuiautomatorkilled': True, 'compresseddump': False}
vc = ViewClient(device, serialno, **kwargs2)

# Title check
try:
    return_text = vc.findViewByIdOrRaise("android:id/action_bar_title").getText()
    if return_text == title_check:
        run_result = "pass"
        print("%s found!" % title_check)
        testcase = title_check + "-Title"
        print("%s Test PASSED!" % testcase)
        collect_score(testcase, run_result)
    else:
        run_result = "fail"
        print("Return text does not match to %s! Please check the screen!" % title_check)
        testcase = title_check + "-Title"
        print("%s Test FAILED!" % testcase)
        collect_score(testcase, run_result)
except ViewNotFoundException:
    run_result = "fail"
    print("%s can not be found! Fatal!" % title_check)
    testcase = title_check + "-Title"
    print("%s Test FAILED!" % testcase)
    collect_score(testcase, run_result)

# First half screen check
for i in range(0, len(item_list)):
    return_object = vc.findViewWithText(item_list[i])
    if return_object is not None:
        run_result = "pass"
        print("%s found!" % item_list[i])
        checked_item.append(item_list[i])
        testcase = item_list[i].replace(" ", "")
        print("%s Test PASSED!" % testcase)
        collect_score(testcase, run_result)
    else:
        missing_item.append(item_list[i])

# Second half screen check
# First click is to capture the focus, second one is to page down
click_counter = 2
if missing_item != []:
    for i in (0, click_counter):
        device.press('KEYCODE_PAGE_DOWN')
        time.sleep(5)
    vc.dump()
    for i in range(0, len(missing_item)):
        return_object = vc.findViewWithText(missing_item[i])
        if return_object is not None:
            run_result = "pass"
            print("%s found!" % missing_item[i])
            checked_item.append(missing_item[i])
            testcase = missing_item[i].replace(" ", "")
            print("%s Test PASSED!" % testcase)
            collect_score(testcase, run_result)
        else:
            run_result = "fail"
            print("%s can not be found!" % missing_item[i])
            checked_item.append(missing_item[i])
            testcase = missing_item[i].replace(" ", "")
            print("%s Test FAILED!" % testcase)
            collect_score(testcase, run_result)
else:
    print("All checked! Test finished!")
    sys.exit(0)

# Examine the total check point number
if len(checked_item) != len(item_list):
    run_result = "fail"
    print("Something is wrong in check point list!")
    testcase = "check-point-number"
    print("%s does not match!" % testcase)
    collect_score(testcase, run_result)
