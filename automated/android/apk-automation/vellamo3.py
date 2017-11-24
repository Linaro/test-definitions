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
                        break

    def execute(self):
        need_continue = True
        while need_continue:
            self.dump_always()
            btn_setup_1 = self.vc.findViewById("android:id/button1")
            btn_settings = self.vc.findViewById('com.quicinc.vellamo:id/main_toolbar_wheel')
            btn_animations = self.vc.findViewWithText(u'Make Vellamo even more beautiful')
            if btn_setup_1:
                # Accept Vellamo EULA
                btn_setup_1.touch()
            elif btn_settings:
                # Open settings
                btn_settings.touch()
            elif btn_animations:
                # Disable animations
                btn_animations.touch()
                need_continue = False

        # Back to the home screen
        self.device.press("KEYCODE_BACK")

        self.logger.info("Benchmark started now")

        chapters = ['Browser', 'Multicore', 'Metal']
        for chapter in chapters:
            self.choose_chapter(chapter)

            # Start benchmark
            self.dump_always()
            try:
                gotit_button = self.vc.findViewWithText(u'GOT IT')
                if gotit_button:
                    gotit_button.touch()
            except ViewNotFoundException:
                self.report_result('vellamo3-%s' % chapter, 'fail')
                self.logger.error('Start button for chapter %s NOT found, moving to the next chapter...')
                continue

            # Wait while Vellamo is running benchmark
            finished = False
            while not finished:
                time.sleep(1)
                try:
                    self.dump_always()
                    goback_btn = self.vc.findViewById("com.quicinc.vellamo:id/main_toolbar_goback_button")
                    if goback_btn:
                        goback_btn.touch()
                        time.sleep(5)
                        finished = True
                except ViewNotFoundException:
                    pass
                except RuntimeError as e:
                    print(e)
                except ValueError as ve:
                    print(ve)

            self.logger.info("Benchmark finished: %s" % chapter)
            self.device.press("KEYCODE_BACK")
            time.sleep(5)
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
