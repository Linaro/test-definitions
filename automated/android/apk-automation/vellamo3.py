import json
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "com.quicinc.vellamo-3.apk"
        self.config['apk_package'] = "com.quicinc.vellamo"
        self.config['activity'] = "com.quicinc.vellamo/.main.MainActivity"
        super(ApkRunnerImpl, self).__init__(self.config)

    def choose_chapter(self, chapter_name):
        # ToDo: scroll screen if chapter is not found on the first screen
        self.dump_always()
        scroll = self.vc.findViewWithText(u'''LET'S ROLL''')
        if scroll:
            print("Click LET'S ROLL")
            scroll.touch()

        chapter_tab = None
        self.dump_always()
        while chapter_tab is None:
            gotit_button = self.vc.findViewWithText(u'GOT IT')
            if gotit_button:
                print("Click GOT IT")
                gotit_button.touch()
            else:
                print("press DPAD_DOWN")
                self.device.press("DPAD_DOWN")
            self.dump_always()
            chapter_tab = self.vc.findViewWithText(chapter_name)

        enclosing_tab = chapter_tab.getParent().getParent()
        for child in enclosing_tab.children:
            if child.getClass() == "android.widget.FrameLayout":
                for subchild in child.children:
                    if subchild.getId() == "com.quicinc.vellamo:id/card_launcher_run_button":
                        subchild.touch()

    def execute(self):
        self.dump_always()
        # Accept Vellamo EULA
        btn_setup_1 = self.vc.findViewByIdOrRaise("android:id/button1")
        btn_setup_1.touch()

        # Open settings
        self.dump_always()
        btn_settings = self.vc.findViewByIdOrRaise('com.quicinc.vellamo:id/main_toolbar_wheel')
        btn_settings.touch()

        # Disable animations
        self.dump_always()
        btn_animations = self.vc.findViewWithTextOrRaise(u'Make Vellamo even more beautiful')
        btn_animations.touch()

        # Back to the home screen
        self.device.press("KEYCODE_BACK")

        chapters = ['Browser', 'Multicore', 'Metal']
        for chapter in chapters:
            self.choose_chapter(chapter)

            # Start benchmark
            self.dump_always()
            btn_start = self.vc.findViewById("com.quicinc.vellamo:id/main_toolbar_operation_button")
            if btn_start:
                btn_start.touch()

            # Wait while Vellamo is running benchmark
            finished = False
            while not finished:
                time.sleep(1)
                try:
                    self.dump_always()
                    goback_title = self.vc.findViewById("com.quicinc.vellamo:id/main_toolbar_goback_title")
                    goback_btn = self.vc.findViewById("com.quicinc.vellamo:id/main_toolbar_goback_button")
                    if goback_btn or goback_title:
                        btn_no = self.vc.findViewByIdOrRaise("com.quicinc.vellamo:id/button_no")
                        btn_no.touch()
                        finished = True
                except ViewNotFoundException:
                    pass
                except RuntimeError as e:
                    print(e)
                except ValueError as ve:
                    print(ve)

            self.logger.info("Benchmark finished: %s" % chapter)
            self.device.press("KEYCODE_BACK")
            self.device.press("KEYCODE_BACK")

    def parseResult(self):
        raw_result_file = '%s/chapterscores-itr%s.json' % (self.config['output'], self.config['itr'])
        self.call_adb('pull /data/data/com.quicinc.vellamo/files/chapterscores.json %s' % raw_result_file)
        default_unit = 'Points'
        # This is one-line file, read it in a whole
        fileopen = open(raw_result_file, 'r')
        jsoncontent = json.load(fileopen)
        result_flag = 'benchmark_results'
        chapter_flag = 'chapter_name'

        total_score = 0
        for item in jsoncontent:
            if result_flag and chapter_flag in item.keys():
                chapter = item[chapter_flag]
                chapter_total = 0
                self.logger.info('%s test result found in category: %s' % (str(len(item[result_flag])), chapter))
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
                        self.report_result("vellamo3-" + testcase, result, str(score), default_unit)
                        chapter_total = chapter_total + score
                    else:
                        print('Corrupted test result found, please check it manually.')
                        print('A valid test result must contain id, score and pass/fail status.')

                self.report_result("vellamo3-" + chapter + "-total", "pass", str(chapter_total), default_unit)
                total_score = total_score + chapter_total
            else:
                print('Cannot find %s or %s in test result dictionary. Please check it manually.' % (result_flag, chapter_flag))

        fileopen.close()
        self.report_result("vellamo3-total-score", "pass", str(total_score), default_unit)
