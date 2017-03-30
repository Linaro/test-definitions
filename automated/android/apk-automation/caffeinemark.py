import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'com.flexycore.caffeinemark-1.apk'
        self.config['apk_package'] = 'com.flexycore.caffeinemark'
        self.config['activity'] = 'com.flexycore.caffeinemark/.Application'
        super(ApkRunnerImpl, self).__init__(self.config)

    def setUp(self):
        self.call_adb('shell setenforce 0')
        super(ApkRunnerImpl, self).setUp()

    def tearDown(self):
        self.call_adb('shell setenforce 1')
        super(ApkRunnerImpl, self).tearDown()

    def execute(self):
        time.sleep(2)
        self.dump_always()
        start_button = self.vc.findViewByIdOrRaise("com.flexycore.caffeinemark:id/startButton")
        start_button.touch()

        finished = False
        while not finished:
            try:
                self.dump_always()
                self.vc.findViewByIdOrRaise("com.flexycore.caffeinemark:id/testResultsCellOneTitle")
                finished = True
            except ViewNotFoundException:
                self.logger.info("ViewNotFoundException when tried to find com.flexycore.caffeinemark:id/testResultsCellOneTitle")
                pass
            except RuntimeError:
                self.logger.info("RuntimeError when tried to find com.flexycore.caffeinemark:id/testResultsCellOneTitle")
                pass
        self.logger.info("benchmark finished")

    def parseResult(self):
        total_score = self.vc.findViewByIdOrRaise("com.flexycore.caffeinemark:id/testResultEntryOverAllScore").getText()
        self.report_result("Caffeinemark-score", 'pass', total_score, 'points')

        details_button = self.vc.findViewByIdOrRaise("com.flexycore.caffeinemark:id/testResultsDetailsButton")
        details_button.touch()

        time.sleep(2)
        self.dump_always()

        sieve_name = self.vc.findViewByIdOrRaise("id/no_id/9").getText()
        sieve_score = self.vc.findViewByIdOrRaise("id/no_id/10").getText()
        self.report_result("Caffeinemark-Sieve-score", 'pass', sieve_score, 'points')

        loop_name = self.vc.findViewByIdOrRaise("id/no_id/13").getText()
        loop_score = self.vc.findViewByIdOrRaise("id/no_id/14").getText()
        self.report_result("Caffeinemark-Loop-score", 'pass', loop_score, 'points')

        logic_name = self.vc.findViewByIdOrRaise("id/no_id/17").getText()
        logic_score = self.vc.findViewByIdOrRaise("id/no_id/18").getText()
        self.report_result("Caffeinemark-Collect-score", 'pass', logic_score, 'points')

        string_name = self.vc.findViewByIdOrRaise("id/no_id/21").getText()
        string_score = self.vc.findViewByIdOrRaise("id/no_id/22").getText()
        self.report_result("Caffeinemark-String-score", 'pass', string_score, 'points')

        float_name = self.vc.findViewByIdOrRaise("id/no_id/25").getText()
        float_score = self.vc.findViewByIdOrRaise("id/no_id/26").getText()
        self.report_result("Caffeinemark-Float-score", 'pass', float_score, 'points')

        method_name = self.vc.findViewByIdOrRaise("id/no_id/29").getText()
        method_score = self.vc.findViewByIdOrRaise("id/no_id/30").getText()
        self.report_result("Caffeinemark-Method-score", 'pass', method_score, 'points')
