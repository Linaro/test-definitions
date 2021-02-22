import re
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config[
            "apk_file_name"
        ] = "JavaBenchmark/pure-java-benchmarks/03-JBench.apk"
        self.config["apk_package"] = "it.JBench.bench"
        self.config["activity"] = "it.JBench.bench/it.JBench.jbench.MainActivity"
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        find_start_btn = False
        while not find_start_btn:
            time.sleep(2)
            self.dump_always()
            btn_jbench = self.vc.findViewById("it.JBench.bench:id/button1")
            warn_msg = self.vc.findViewWithText(
                u"This app was built for an older version of Android and may not work properly. Try checking for updates, or contact the developer."
            )
            continue_btn = self.vc.findViewWithText(u"CONTINUE")
            if warn_msg:
                self.logger.info("Older version warning popped up")
                warning_ok_btn = self.vc.findViewWithTextOrRaise(u"OK")
                warning_ok_btn.touch()
            elif continue_btn:
                continue_btn.touch()
            elif btn_jbench:
                btn_jbench.touch()
                find_start_btn = True
            else:
                self.logger.info("Nothing found, need to check manually")

        finished = False
        while not finished:
            try:
                time.sleep(5)
                self.dump_always()
                results = self.vc.findViewByIdOrRaise(
                    "it.JBench.bench:id/textViewResult"
                )
                if re.search(r"^\d+$", results.getText()):
                    finished = True
                    print("benchmark finished")
                    print("%s=%s" % ("JBench", results.getText().strip()))
                    self.report_result(
                        "jbench", "pass", results.getText().strip(), "points"
                    )
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass

    def parseResult(self):
        pass
