import time
import xml.dom.minidom
from common import ApkTestRunner


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'GLBenchmark_2.5.1.apk'
        self.config['apk_package'] = 'com.glbenchmark.glbenchmark25'
        self.config['activity'] = 'com.glbenchmark.glbenchmark25/com.glbenchmark.activities.GLBenchmarkDownloaderActivity'
        super(ApkRunnerImpl, self).__init__(self.config)

    def setUp(self):
        # set to peformance governor policay
        self.set_performance_governor()
        # download apk related files
        self.download_apk('main.1.com.glbenchmark.glbenchmark25.obb')
        self.download_apk(self.config['apk_file_name'])
        self.uninstall_apk(self.config['apk_package'])
        self.install_apk(self.config['apk_file_name'])

        # Push data and config files.
        self.logger.info('Pushing main.1.com.glbenchmark.glbenchmark25.obb to target...')
        self.call_adb('push %s/main.1.com.glbenchmark.glbenchmark25.obb /sdcard/Android/obb/com.glbenchmark.glbenchmark25/main.1.com.glbenchmark.glbenchmark25.obb' % self.config['apk_dir'])
        self.logger.info('Pushing glbenchmark25-preferences.xml to target...')
        self.call_adb('push ./glbenchmark25-preferences.xml /data/data/com.glbenchmark.glbenchmark25/shared_prefs/com.glbenchmark.glbenchmark25_preferences.xml')

        # Clear logcat buffer.
        self.call_adb("logcat -c")
        self.call_adb("logcat -b events -c")
        time.sleep(3)

        # Start intent.
        self.logger.info('Starting %s' % self.config['apk_package'])
        self.call_adb("shell am start -W -S %s" % self.config['activity'])

    def execute(self):
        selected_all = False
        while not selected_all:
            self.dump_always()
            select_all_btn = self.vc.findViewWithText("All")
            display_tests_menu = self.vc.findViewWithText("Performance Tests")
            if select_all_btn:
                select_all_btn.touch()
                self.logger.info("All selected!")
                selected_all = True
            elif display_tests_menu:
                display_tests_menu.touch()
                self.logger.info("Display all tests to select all")
            else:
                # continue
                pass

        # Disable crashed test suites
        self.dump_always()
        crashed_test_name = "C24Z24MS4"
        self.logger.info('Test suite %s is going to be disabled!' % crashed_test_name)
        crashed_test = self.vc.findViewWithText(crashed_test_name)
        if crashed_test is not None:
            crashed_test.touch()
            self.logger.info('Test suite %s has been excluded!' % crashed_test_name)
        else:
            self.logger.info('Can not find test suite %s, please check the screen!' % crashed_test_name)

        # Start selected test suites
        self.dump_always()
        start_button = self.vc.findViewByIdOrRaise("com.glbenchmark.glbenchmark25:id/buttonStart")
        start_button.touch()

        finished = False
        while not finished:
            time.sleep(120)
            self.dump_always()
            flag = self.vc.findViewWithText("Result processing")
            if flag is not None:
                self.logger.info('GLBenchmark Test Finished.')
                finished = True
                # Give up the result upload
                cancel_button = self.vc.findViewWithText("Cancel")
                if cancel_button is not None:
                    cancel_button.touch()
                    time.sleep(5)
                else:
                    self.logger.error('Can not find cancel button! Please check the pop up window!')
            else:
                self.logger.info('GLBenchmark Test is still in progress...')

    def getText(self, node):
        children = node.childNodes
        rc = []
        for node in children:
            if node.nodeType == node.TEXT_NODE:
                rc.append(node.data)
        return ''.join(rc)

    def logparser(self, cached_result_file):
        run_result = 'pass'
        dom = xml.dom.minidom.parse(cached_result_file)
        results = dom.getElementsByTagName('test_result')

        for test in results:
            title = self.getText(test.getElementsByTagName('title')[0])
            test_type = self.getText(test.getElementsByTagName('type')[0])
            score_number = self.getText(test.getElementsByTagName('score')[0])
            fps = self.getText(test.getElementsByTagName('fps')[0])
            score_unit = self.getText(test.getElementsByTagName('uom')[0])
            benchmark_name = title.replace(" ", "-").replace(":", "") + "-" + test_type.replace(" ", "-").replace(":", "")
            self.report_result(benchmark_name, run_result, score_number, score_unit)

            if fps != "":
                score_number = fps.split(" ")[0]
                score_unit = fps.split(" ")[1]
                self.report_result(benchmark_name, run_result, score_number, score_unit)

    def parseResult(self):
        cached_result_file = '%s/last-results-2.5.1-itr%s.xml' % (self.config['output'], self.config['itr'])
        self.logger.info('pull /data/data/com.glbenchmark.glbenchmark25/cache/last_results_2.5.1.xml to output directory...')
        self.call_adb('pull /data/data/com.glbenchmark.glbenchmark25/cache/last_results_2.5.1.xml %s' % cached_result_file)

        self.logparser(cached_result_file)
