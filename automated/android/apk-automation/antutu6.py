import time
from common import ApkTestRunner

#parent_dir = os.path.realpath(os.path.dirname(__file__))
#f_output_result = "%s/../common/output-test-result.sh" % parent_dir


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self):
        self.name = "antutu6"
        test_items = [u'3D', u'UX', u'CPU', u'RAM']
        test_subitems = {
            u'3D' : [u'3D [Garden]', u'3D [Marooned]'],
            u'UX' : [u'UX Data Secure', u'UX Data process', u'UX Strategy games', u'UX Image process', u'UX I/O performance'],
            u'CPU' : [u'CPU Mathematics', u'CPU Common Use', u'CPU Multi-Core'],
            u'RAM' : []
        }
        self.antutu_sum = 0
        self.apk_3d_name="antutu_benchmark_v6_3d_f1.apk"
        self.apk_3d_pkg="com.antutu.benchmark.full"
        super(ApkRunnerImpl, self).__init__(self.name)
        self.activity = "com.antutu.ABenchMark/.ABenchMarkStart"
        self.apk_file_name = "AnTuTu6.0.4.apk"
        self.apk_package = "com.antutu.ABenchMark"


    def setUp(self):
        super(ApkRunnerImpl, self).setUp()
        self.download_apk(self.apk_3d_name)
        base_path = os.path.join(os.path.abspath(APK_DIR), self.apk_3d_name)
        self.call_adb("install %s" % base_path)

    def tearDown(self):
        super(ApkRunnerImpl, self).tearDown()
        self.call_adb("shell am force-stop %s" % self.apk_3d_name)
        self.call_adb("shell pm uninstall %s" % self.apk_3d_pkg)

    def parseResult(self):
        for item in self.test_items:
            print("Try to find result for test suite: %s" % item)
            found_view = False
            while not found_view:
                self.dump_always()
                id_root = self.vc.findViewWithText(item)
                if id_root:
                    print("Found result id_root for test suite: %s" % item)
                    found_view = True
                else:
                    self.dump_always()
                    print("Press DPAD_DOWN to find %s item" % item)
                    self.device.press('DPAD_DOWN')
                    time.sleep(2)

            print("Try to find the score value for test suite:%s" % item)
            # Try to find the score for that item
            found_view = False
            while not found_view:
                self.dump_always()
                id_root = self.vc.findViewWithText(item)
                score_view = self.vc.findViewById("com.antutu.ABenchMark:id/tv_score_value",
                                         id_root.getParent())
                if score_view:
                    score = score_view.getText().strip()
                    #try:
                    score = int(score)
                    #call([f_output_result, "antutu6_%s" % item.upper(), 'pass', str(score), 'points'])
                    self.antutu_sum = self.antutu_sum + int(score)
                    #except ValueError:
                    #call([f_output_result, "antutu6_%s" % item.upper(), 'fail'])

                    found_view = True
                    arrow_icon = self.vc.findViewById("com.antutu.ABenchMark:id/iv_arrow", id_root.getParent())
                    if arrow_icon:
                        arrow_icon.touch()

                    self.logger.info("Found score value for test suite: %s: %s" % (item, score))

                else:
                    self.logger.info("Press DPAD_DOWN to find %s item value" % item.lower())
                    self.device.press('DPAD_DOWN')
                    time.sleep(2)


            for sub_item in self.test_subitems[item]:

                print("Try to find score value for sub item: %s" % sub_item)
                found_view = False
                while not found_view:
                    self.dump_always()
                    subitem_obj = self.vc.findViewWithText(sub_item)
                    if subitem_obj:
                        subitem_value_obj = self.vc.findViewByIdOrRaise("com.antutu.ABenchMark:id/tv_value", subitem_obj.getParent())
                        subitem_key = sub_item.replace("[", '').replace("]", '')
                        subitem_key = subitem_key.replace("/", '')
                        subitem_score = subitem_value_obj.getText().strip()
                        #try:
                        subitem_score = int(subitem_score)
                        #    call([f_output_result, "antutu6_%s" % subitem_key,
                        #            'pass', str(subitem_score), 'points'])
                        #except ValueError:
                        #    call([f_output_result, "antutu6_%s" % subitem_key, 'fail'])

                        found_view = True
                        self.logger.info("Found score value for sub itme: %s : %s" % (sub_item, subitem_score))
                    else:
                        self.logger.info("Press DPAD_DOWN to find sub item: %s" % sub_item)
                        self.device.press('DPAD_DOWN')
                        time.sleep(2)

    def execute(self):
        #Enable 64-bit
        time.sleep(10)

        finished = False
        while not finished:
            self.dump_always()
            test_region = self.vc.findViewById("com.antutu.ABenchMark:"
                                          "id/start_test_region")
            if test_region:
                test_region.touch()

            time.sleep(30)
            self.dump_always()
            text_qr_code = self.vc.findViewWithText(u'QRCode of result')
            if text_qr_code:
                finished = True
                print("Benchmark test finished!")

            stop_msg = 'Unfortunately, AnTuTu 3DBench has stopped.'
            msg_stopped = self.vc.findViewWithText(stop_msg)
            if msg_stopped:
                btn_ok = vc.findViewWithTextOrRaise(u'OK')
                btn_ok.touch()

            # cancel the update
            update_msg = "New update available"
            update_window = self.vc.findViewWithText(update_msg)
            if update_window:
                btn_cancel = self.vc.findViewWithTextOrRaise(u'Cancel')
                btn_cancel.touch()

            msg = "Please allow the permissions we need for test"
            need_permission_msg = self.vc.findViewWithText(msg)
            if need_permission_msg:
                btn_ok = self.vc.findViewWithTextOrRaise(u'OK')
                btn_ok.touch()

            allow_permission_btn = self.vc.findViewById('com.android.packageinstaller'
                                                   ':id/permission_allow_button')
            if allow_permission_btn:
                allow_permission_btn.touch()
