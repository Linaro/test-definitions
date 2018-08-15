import sys
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "gr.androiddev.BenchmarkPi-1.apk"
        self.config['apk_package'] = "gr.androiddev.BenchmarkPi"
        self.config['activity'] = "gr.androiddev.BenchmarkPi/.BenchmarkPi"
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
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
                start_button = self.vc.findViewByIdOrRaise("gr.androiddev.BenchmarkPi:id/Button01")
                start_button.touch()
                find_start_btn = True

        finished = False
        while not finished:
            time.sleep(1)
            try:
                self.vc.dump(window='-1')
                self.vc.findViewByIdOrRaise("android:id/message")
                finished = True
            except ViewNotFoundException:
                pass
            except RuntimeError as e:
                self.logger.error(e)
        self.logger.info('benchmark pi finished')

    def parseResult(self):
        return_text = self.vc.findViewByIdOrRaise("android:id/message").getText().split(" ")

        flagwordA = "calculated"
        flagwordB = "Pi"

        if flagwordA in return_text and flagwordB in return_text:
            if return_text.index(flagwordB) == return_text.index(flagwordA) + 1:
                score_number = return_text[return_text.index(flagwordA) + 3]
                score_unit = return_text[return_text.index(flagwordA) + 4].split("!")[0]
                self.logger.info('Valid test result found: %s %s' % (score_number, score_unit))
                run_result = "pass"
            else:
                self.logger.error("Output string changed, parser need to be updated!")
                sys.exit(1)
        else:
            self.logger.error("Can not find keyword which is supposed to show up!")
            sys.exit(1)

        self.report_result('benchmarkpi', run_result, score_number, score_unit)
