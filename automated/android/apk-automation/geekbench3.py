import glob
import os
import sys
import shutil
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "com.primatelabs.geekbench3.apk"
        self.config['apk_package'] = "com.primatelabs.geekbench3"
        self.config['activity'] = "com.primatelabs.geekbench3/.HomeActivity"
        super(ApkRunnerImpl, self).__init__(self.config)

    def all_fail(self):
        self.report_result('geekbench-run', 'fail')
        self.report_result('geekbench-single-core', 'skip')
        self.report_result('geekbench-multi-core', 'skip')

    def execute(self):
        try:
            time.sleep(2)
            self.dump_always()
            trigger = self.vc.findViewByIdOrRaise(self.config['apk_package'] + ":id/runBenchmarks")
            trigger.touch()
            self.logger.info("Geekbench 3 Test Started!")
        except ViewNotFoundException:
            self.logger.error("Can not find the start button! Please check the screen!")
            self.all_fail()
            sys.exit(1)

        finished = False
        while (not finished):
            time.sleep(10)
            self.dump_always()
            flag = self.vc.findViewWithText("RESULT")
            in_progress = self.vc.findViewById("android:id/progress")
            if flag is not None:
                self.logger.info("Geekbench 3 Test Finished!")
                finished = True
            elif in_progress:
                self.logger.info("Geekbench 3 Test is still in progress...")
            else:
                self.logger.error("Something goes wrong! It is unusual that the test has not been started after 10+ seconds! Please manually check it!")
                #self.all_fail()
                #sys.exit(1)

        # Generate the .gb3 file
        self.device.press('KEYCODE_MENU')
        time.sleep(1)
        self.dump_always()
        share_button = self.vc.findViewWithText("Share")
        if share_button is not None:
            share_button.touch()
            time.sleep(5)
        else:
            self.logger.error("Can not find the Share button to generate .gb3 file! Please check the screen!")
            sys.exit(1)

    def parseResult(self):
        raw_output_file = '%s/geekbench3-result-itr%s.gb3' % (self.config['output'], self.config['itr'])
        self.logger.info('Pulling /data/user/0/com.primatelabs.geekbench3/files to output directory...')
        self.call_adb('pull /data/user/0/com.primatelabs.geekbench3/files %s/files' % self.config['output'])
        db_file_list = glob.glob('%s/files/*.gb3' % self.config['output'])
        if len(db_file_list) > 1:
            self.logger.error('More then one db file found...')
            sys.exit(1)
        db_file = db_file_list[0]
        os.rename(db_file, raw_output_file)

        singlecore_keyword = "score"
        singlecore_result = {}
        multicore_keyword = "multicore_score"
        multicore_result = {}
        endpoint_keyword = "multicore_rate"

        if os.path.exists(raw_output_file):
            logfile = open(raw_output_file, "r")
            for line in logfile:
                # Can't believe this is an one line file!
                # Find the ending point with the information we want
                endpoint = line.find(endpoint_keyword)
                if endpoint == -1:
                    self.logger.error("Can not find %s in log file! Please manually check it!" % endpoint_keyword)
                    self.all_fail()
                    sys.exit(1)
                else:
                    self.report_result("geekbench-run", "pass")
                    result_cut = line[0:endpoint].split(",")
                    result_cut = [element.replace('"', '').replace(' ', '') for element in result_cut]
                    for item in result_cut:
                        if singlecore_keyword == item.split(":")[0]:
                            singlecore_result[singlecore_keyword] = item.split(":")[1]
                        if multicore_keyword == item.split(":")[0]:
                            multicore_result[multicore_keyword] = item.split(":")[1]
                    if len(singlecore_result) != 1:
                        run_result = "fail"
                        self.logger.error("Incorrect value for single core test result! Please check the test result file!")
                        self.report_result('geekbench-single-core', run_result)
                    else:
                        run_result = "pass"
                        self.report_result('geekbench-single-core', run_result, singlecore_result[singlecore_keyword], 'points')
                    if len(multicore_result) != 1:
                        run_result = "fail"
                        self.logger.error("Incorrect value for multi core test result! Please check the test result file!")
                        self.report_result('geekbench-multi-core', run_result)
                    else:
                        run_result = "pass"
                        self.report_result('geekbench-multi-core', run_result, multicore_result[multicore_keyword], 'points')

            logfile.close()
        else:
            self.logger.error("Result file does not exist: %s" % raw_output_file)
            sys.exit(1)

    def tearDown(self):
        super(ApkRunnerImpl, self).tearDown()
        shutil.rmtree('%s/files/' % self.config['output'])
