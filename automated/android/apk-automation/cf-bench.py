import re
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'CF-Bench-Pro-1.3.apk'
        self.config['apk_package'] = 'eu.chainfire.cfbench'
        self.config['activity'] = 'eu.chainfire.cfbench/.MainActivity'
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        time.sleep(2)
        self.dump_always()

        # Start test button
        start_button = self.vc.findViewWithTextOrRaise("Full Benchmark")
        start_button.touch()

        # Wait while cf-bench running
        finished = False
        while not finished:
            try:
                time.sleep(5)
                self.dump_always()
                self.vc.findViewByIdOrRaise("eu.chainfire.cfbench:id/admob_preference_layout")
                finished = True
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass
        print("Benchmark Finished")

    def parseResult(self):
        def get_score_with_content_desc(content_desc, offset=1):
            try:
                found_score_view = False
                while not found_score_view:
                    score_view = self.vc.findViewWithText(content_desc)
                    if not score_view:
                        self.device.press('DPAD_DOWN')
                        time.sleep(2)
                        try:
                            self.dump_always()
                        except RuntimeError:
                            pass
                        except ValueError:
                            pass
                    else:
                        found_score_view = True

                score_uid = score_view.getUniqueId()
                uid = int(re.search("id/no_id/(?P<uid>\d+)", score_uid).group('uid'))
                score = self.vc.findViewByIdOrRaise("id/no_id/%s" % (uid + offset))
                score_text = score.getText()
                if score_text.find("%") > 0:
                    score_value, units = score_text.split(" ")
                    self.report_result("cfbench-" + content_desc.replace(" ", "-"), 'pass', score_value, units)

                else:
                    self.report_result("cfbench-" + content_desc.replace(" ", "-"), 'pass', score_text, 'points')
            except ViewNotFoundException:
                print("%s not found" % content_desc)
                pass

        # Fetch Scores
        get_score_with_content_desc("Native MIPS")
        get_score_with_content_desc("Java MIPS")
        get_score_with_content_desc("Native MSFLOPS")
        get_score_with_content_desc("Java MSFLOPS")
        get_score_with_content_desc("Native MDFLOPS")
        get_score_with_content_desc("Java MDFLOPS")
        get_score_with_content_desc("Native MALLOCS")
        get_score_with_content_desc("Native Memory Read")
        get_score_with_content_desc("Java Memory Read")
        get_score_with_content_desc("Native Memory Write")
        get_score_with_content_desc("Java Memory Write")
        get_score_with_content_desc("Native Disk Read")
        get_score_with_content_desc("Native Disk Write")
        get_score_with_content_desc("Java Efficiency MIPS")
        get_score_with_content_desc("Java Efficiency MSFLOPS")
        get_score_with_content_desc("Java Efficiency MDFLOPS")
        get_score_with_content_desc("Java Efficiency Memory Read")
        get_score_with_content_desc("Java Efficiency Memory Write")
        get_score_with_content_desc("Native Score")
        get_score_with_content_desc("Java Score")
        get_score_with_content_desc("Overall Score")
