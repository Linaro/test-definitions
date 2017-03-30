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
        time.sleep(2)
        self.dump_always()
        start_single_button = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/btnsingle")
        start_single_button.touch()

        time.sleep(2)
        self.dump_always()
        start_single_button = self.vc.findViewById("com.greenecomputing.linpack:id/btnsingle")

        while not start_single_button:
            time.sleep(2)
            self.dump_always()
            start_single_button = self.vc.findViewById("com.greenecomputing.linpack:id/btnsingle")

        mflops_single_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txtmflops_result")
        time_single_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txttime_result")
        self.report_result('Linpack-MFLOPSSingleScore', 'pass', mflops_single_score.getText(), 'MFLOPS')
        self.report_result('Linpack-TimeSingleScore', 'pass', time_single_score.getText(), 'seconds')

        # Multi core test.
        self.dump_always()
        start_multi_button = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/btncalculate")
        start_multi_button.touch()

        time.sleep(2)
        self.dump_always()
        start_single_button = self.vc.findViewById("com.greenecomputing.linpack:id/btnsingle")

        while not start_single_button:
            time.sleep(2)
            self.dump_always()
            start_single_button = self.vc.findViewById("com.greenecomputing.linpack:id/btnsingle")

        mflops_multi_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txtmflops_result")
        time_multi_score = self.vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txttime_result")
        self.report_result('Linpack-MFLOPSMultiScore', 'pass', mflops_multi_score.getText(), 'MFLOPS')
        self.report_result('Linpack-TimeMultiScore', 'pass', time_multi_score.getText(), 'seconds')

    def parseResult(self):
        pass
