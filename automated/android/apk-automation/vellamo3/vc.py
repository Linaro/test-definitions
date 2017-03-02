#!/usr/bin/env python
# Author:
# Milosz Wasilewski <milosz.wasilewski@linaro.org>
# Botao Sun <botao.sun@linaro.org>
import os
import sys
import time
import json
from subprocess import call
from com.dtmilano.android.viewclient import ViewClient, ViewNotFoundException

parent_dir = os.path.realpath(os.path.dirname(__file__))
f_output_result = "%s/../common/output-test-result.sh" % parent_dir

kwargs1 = {'verbose': True, 'ignoresecuredevice': False}
device, serialno = ViewClient.connectToDeviceOrExit(**kwargs1)
kwargs2 = {'startviewserver': True, 'forceviewserveruse': False, 'autodump': False, 'ignoreuiautomatorkilled': True, 'compresseddump': False}

vc = ViewClient(device, serialno, **kwargs2)

# Result collection for LAVA
default_unit = 'Points'


def extract_scores(filename):
    # This is one-line file, read it in a whole
    fileopen = open(filename, 'r')
    jsoncontent = json.load(fileopen)
    result_flag = 'benchmark_results'
    chapter_flag = 'chapter_name'

    total_score = 0
    for item in jsoncontent:
        if result_flag and chapter_flag in item.keys():
            chapter = item[chapter_flag]
            chapter_total = 0
            print('%s test result found in category: %s' % (str(len(item[result_flag])), chapter))
            for elem in item[result_flag]:
                if 'failed' in elem.keys() and 'id' in elem.keys() and 'score' in elem.keys():
                    # Pick up the result
                    if elem['failed'] is False:
                        result = 'pass'
                    else:
                        result = 'fail'
                    # Pick up the full test name
                    testcase = chapter + '-' + elem['id']
                    # Pick up the test score
                    score = elem['score']
                    # Submit the result to LAVA
                    call([f_output_result, "vellamo3_" + testcase, result, str(score), default_unit])
                    chapter_total = chapter_total + score
                else:
                    print 'Corrupted test result found, please check it manually.'
                    print 'A valid test result must contain id, score and pass/fail status.'

            call([f_output_result, "vellamo3_" + chapter + "_total", "pass", str(chapter_total), default_unit])
            total_score = total_score + chapter_total

        else:
            print 'Cannot find ' + result_flag + ' or ' + chapter_flag + ' in test result dictionary. Please check it manually.'
    fileopen.close()
    call([f_output_result, "vellamo3_total_score", "pass", str(total_score), default_unit])


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


def choose_chapter(vc, chapter_name):
    # ToDo: scroll screen if chapter is not found on the first screen
    dump_always()
    scroll = vc.findViewWithText(u'''LET'S ROLL''')
    if scroll:
        print("Click LET'S ROLL")
        scroll.touch()

    chapter_tab = None
    dump_always()
    while chapter_tab is None:
        gotit_button = vc.findViewWithText(u'GOT IT')
        if gotit_button:
            print("Click GOT IT")
            gotit_button.touch()
        else:
            print("press DPAD_DOWN")
            device.press("DPAD_DOWN")
        dump_always()
        chapter_tab = vc.findViewWithText(chapter_name)

    enclosing_tab = chapter_tab.getParent().getParent()
    for child in enclosing_tab.children:
        if child.getClass() == "android.widget.FrameLayout":
            for subchild in child.children:
                if subchild.getId() == "com.quicinc.vellamo:id/card_launcher_run_button":
                    subchild.touch()


dump_always()
# Accept Vellamo EULA
btn_setup_1 = vc.findViewByIdOrRaise("android:id/button1")
btn_setup_1.touch()

# open settings
dump_always()
btn_settings = vc.findViewByIdOrRaise('com.quicinc.vellamo:id/main_toolbar_wheel')
btn_settings.touch()

# disable animations
dump_always()
btn_animations = vc.findViewWithTextOrRaise(u'Make Vellamo even more beautiful')
btn_animations.touch()

# back to the home screen
device.press("KEYCODE_BACK")

chapters = ['Browser', 'Multicore', 'Metal']
for chapter in chapters:

    choose_chapter(vc, chapter)

    # Start benchmark
    dump_always()
    btn_start = vc.findViewById("com.quicinc.vellamo:id/main_toolbar_operation_button")
    if btn_start:
        btn_start.touch()

    # Wait while Vellamo is running benchmark
    finished = False
    while (not finished):
        time.sleep(1)
        try:
            dump_always()
            goback_title = vc.findViewById("com.quicinc.vellamo:id/main_toolbar_goback_title")
            goback_btn = vc.findViewById("com.quicinc.vellamo:id/main_toolbar_goback_button")
            if goback_btn or goback_title:
                btn_no = vc.findViewByIdOrRaise("com.quicinc.vellamo:id/button_no")
                btn_no.touch()
                finished = True
        except ViewNotFoundException:
            pass
        except RuntimeError as e:
            print e
        except ValueError as ve:
            print ve

    print "Benchmark finished: %s" % chapter
    device.press("KEYCODE_BACK")
    device.press("KEYCODE_BACK")

return_value = call(['%s/get_result.sh' % parent_dir])
if return_value == 0:
    extract_scores(filename='chapterscores.json')
else:
    print 'Test result file transfer failed!'
    sys.exit(1)
