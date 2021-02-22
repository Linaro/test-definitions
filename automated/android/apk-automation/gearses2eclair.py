import re
import sys
import time
from common import ApkTestRunner


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config["apk_file_name"] = "GearsES2eclair-20141021.apk"
        self.config["apk_package"] = "com.jeffboody.GearsES2eclair"
        self.config["activity"] = "com.jeffboody.GearsES2eclair/.GearsES2eclair"
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        self.logger.info("Running GearsES2eclair for 60 seconds...")
        self.dump_always()

        message_obj = self.vc.findViewWithText(
            u"This app was built for an older version of Android and may not work properly. Try checking for updates, or contact the developer."
        )
        if message_obj:
            button1 = self.vc.findViewWithTextOrRaise(u"OK")
            button1.touch()
        time.sleep(60)

    def parseResult(self):
        raw_output_file = "%s/logcat-gearses2eclair-itr%s.log" % (
            self.config["output"],
            self.config["itr"],
        )
        self.call_adb("logcat -d > %s" % raw_output_file)

        # 08-29 01:25:29.491  4704  4728 I a3d     : a3d_GLES_dump@566 fps=58
        fps_pattern = re.compile(r"^.*\s+:\s+a3d_GLES_dump@\d+\s+fps=(?P<fps>\d+)\s*$")

        result_collector = []
        with open(raw_output_file, "r") as logfile:
            for line in logfile:
                matches = fps_pattern.match(line)
                if matches:
                    result_collector.append(matches.group("fps"))

        self.logger.info("result_collector: %s" % result_collector)
        if len(result_collector) > 0:
            average_fps = sum(float(element) for element in result_collector) / len(
                result_collector
            )
            score_number = average_fps
            run_result = "pass"
            self.logger.info(
                "The average FPS in this test run is %s" % str(score_number)
            )
        else:
            self.logger.error("The collector is empty, no actual result received!")
            sys.exit(1)

        self.report_result("gearses2eclair", run_result, score_number, "fps")
