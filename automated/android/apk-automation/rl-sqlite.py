import time
from common import ApkTestRunner


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'RL_Benchmark_SQLite_v1.3.apk'
        self.config['apk_package'] = 'com.redlicense.benchmark.sqlite'
        self.config['activity'] = 'com.redlicense.benchmark.sqlite/.Main'
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        self.dump_always()
        btn_start = self.vc.findViewWithTextOrRaise(u'Start')
        btn_start.touch()

        finished = False
        while(not finished):
            self.dump_always()
            overall_result = self.vc.findViewWithText(u'Overall')
            if overall_result:
                finished = True
                self.logger.info("benchmark finished")

    def __get_score_with_text(self, text):
        found_score_view = False
        while not found_score_view:
            linear_layout = self.vc.findViewByIdOrRaise("com.redlicense.benchmark.sqlite:id/stats")
            for ch in linear_layout.children:
                subitem = self.vc.findViewWithText(text, ch)
                if subitem:
                    subitem_result = self.vc.findViewByIdOrRaise("com.redlicense.benchmark.sqlite:id/test_result", ch)
                    score = subitem_result.getText().replace("sec", "").replace("Running", "").strip()
                    score_in_ms = float(score) * 1000
                    self.report_result("RL-sqlite-" + text.replace(" ", "-"), 'pass', str(score_in_ms), "ms")
                    found_score_view = True
                    break
            if subitem is None:
                self.logger.info("%s not found, need to pageup" % text)
                self.device.press('DPAD_UP')
                time.sleep(2)
                self.device.press('DPAD_UP')
                time.sleep(2)
                self.dump_always()

    def parseResult(self):
        self.__get_score_with_text("Overall")
        self.__get_score_with_text("DROP TABLE")
        self.__get_score_with_text("DELETE with an index")
        self.__get_score_with_text("DELETE without an index")
        self.__get_score_with_text("INSERTs from a SELECT")
        self.__get_score_with_text("25000 UPDATEs with an index")
        self.__get_score_with_text("1000 UPDATEs without an index")
        self.__get_score_with_text("5000 SELECTs with an index")
        self.__get_score_with_text("Creating an index")
        self.__get_score_with_text("100 SELECTs on a string comparison")
        self.__get_score_with_text("100 SELECTs without an index")
        self.__get_score_with_text("25000 INSERTs into an indexed table in a transaction")
        self.__get_score_with_text("25000 INSERTs in a transaction")
        self.__get_score_with_text("1000 INSERTs")
