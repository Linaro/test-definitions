import time
from common import ApkTestRunner


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "com.greenecomputing.linpack-1.apk"
        self.config['apk_package'] = "com.greenecomputing.linpack"
        self.config['activity'] = "com.greenecomputing.linpack/.Linpack"
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        # single core test.
        find_start_btn = False
        while not find_start_btn:
            time.sleep(2)
            self.dump_always()
            warn_msg = self.vc.findViewWithText(u'This app was built for an older version of Android and may not work properly. Try checking for updates, or contact the developer.')
            if warn_msg:
                self.logger.info("Older version warning popped up")
                warning_ok_btn = self.vc.findViewWithTextOrRaise(u'OK')
                warning_ok_btn.touch()
            else:
                start_single_button = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/btnsingle")
                start_single_button.touch()
                find_start_btn = True

        # using start_single_button to check if the test finished
        test_finished = False
        while not test_finished:
            time.sleep(2)
            self.dump_always()
            if self.vc.findViewById("com.greenecomputing.linpack:id/btnsingle"):
                test_finished = True

        mflops_single_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txtmflops_result")
        time_single_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txttime_result")
        self.report_result('Linpack-MFLOPSSingleScore', 'pass', mflops_single_score.getText(), 'MFLOPS')
        self.report_result('Linpack-TimeSingleScore', 'pass', time_single_score.getText(), 'seconds')

        # Multi core test.
        self.dump_always()
        start_multi_button = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/btncalculate")
        start_multi_button.touch()

        # using start_single_button to check if the test finished
        test_finished = False
        while not test_finished:
            time.sleep(2)
            self.dump_always()
            if self.vc.findViewById("com.greenecomputing.linpack:id/btnsingle"):
                test_finished = True

        mflops_multi_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txtmflops_result")
        time_multi_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txttime_result")
        self.report_result('Linpack-MFLOPSMultiScore', 'pass', mflops_multi_score.getText(), 'MFLOPS')
        self.report_result('Linpack-TimeMultiScore', 'pass', time_multi_score.getText(), 'seconds')

    def parseResult(self):
        pass
