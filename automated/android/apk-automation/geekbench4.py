import glob
import json
import os
import sys
import shutil
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException

## geekbench-3-4-3-0.apk
## Version is 4.3.0
## size: 100459959
## md5sum: c0013d79b8518edcdbcf7a2019d2e0ca
## Url:
##   https://geekbench-3.en.uptodown.com/android
##   https://play.google.com/store/apps/details?id=com.primatelabs.geekbench


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "geekbench-3-4-3-0.apk"
        self.config['apk_package'] = "com.primatelabs.geekbench"
        self.config['activity'] = "com.primatelabs.geekbench/.HomeActivity"
        super(ApkRunnerImpl, self).__init__(self.config)

    def all_fail(self):
        self.report_result('geekbench-run', 'fail')
        self.report_result('geekbench-single-core', 'skip')
        self.report_result('geekbench-multi-core', 'skip')

    def execute(self):
        find_run_btn = False
        while not find_run_btn:
            time.sleep(5)
            self.dump_always()
            agreement = self.vc.findViewWithText(u'By using Geekbench you are agreeing to the terms of the Geekbench End User License Agreement and Privacy Policy.')
            if agreement:
                accept_btn = self.vc.findViewWithTextOrRaise(u'ACCEPT')
                accept_btn.touch()
                continue

            no_internet = self.vc.findViewWithText(u'Geekbench encountered an error communicating with the Geekbench Browser. Geekbench requires an active internet connection in order to run benchmarks.')
            if no_internet:
                self.logger.info("Geekbench requires an active internet connection in order to run benchmarks!")
                self.all_fail()
                sys.exit(1)

            runBench = self.vc.findViewWithText(u'RUN CPU BENCHMARK')
            if runBench:
                runBench.touch()
                find_run_btn = True
                self.logger.info("Geekbench 4 Test Started!")

        finished = False
        while (not finished):
            time.sleep(10)
            self.dump_always()
            progress = self.vc.findViewById("android:id/progress")
            progress_percent = self.vc.findViewById("android:id/progress_percent")
            if progress or progress_percent:
                self.logger.info("Geekbench 4 Test is still in progress...")
                continue

            geekbench_score = self.vc.findViewWithText(u'Geekbench Score')
            if geekbench_score:
                self.logger.info("Geekbench 4 Test Finished!")
                finished = True
                continue

            self.logger.error("Something goes wrong! It is unusual that the test has not been started after 10+ seconds! Please manually check it!")
            #self.all_fail()
            #sys.exit(1)

    def parseResult(self):
        raw_output_file = '%s/geekbench3-result-itr%s.json' % (self.config['output'], self.config['itr'])
        self.logger.info('Pulling /data/user/0/com.primatelabs.geekbench/files to output directory...')
        self.call_adb('pull /data/user/0/com.primatelabs.geekbench/files %s/files' % self.config['output'])
        db_file_list = glob.glob('%s/files/*.gb4' % self.config['output'])
        if len(db_file_list) > 1:
            self.logger.error('More then one db file found...')
            sys.exit(1)
        db_file = db_file_list[0]
        os.rename(db_file, raw_output_file)

        if os.path.exists(raw_output_file):
            with open(raw_output_file, "r") as read_file:
                res_data = json.load(read_file)
                for sec in res_data['sections']:
                    self.report_result("Geekbench4-%s" % sec["name"], "pass", sec["score"], 'points')
                    sub_testcases = sec['workloads']
                    for sub_testcase in sub_testcases:
                        self.report_result("Geekbench4-%s-%s" % (sec["name"], sub_testcase["name"].replace(' ', '_')), "pass", sub_testcase["score"], 'points')
        else:
            self.logger.error("Result file does not exist: %s" % raw_output_file)
            sys.exit(1)

    def tearDown(self):
        super(ApkRunnerImpl, self).tearDown()
        shutil.rmtree('%s/files/' % self.config['output'])
