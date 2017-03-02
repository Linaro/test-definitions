import os
import time
from subprocess import call

from com.dtmilano.android.viewclient import ViewClient

parent_dir = os.path.realpath(os.path.dirname(__file__))
f_output_result = "%s/../common/output-test-result.sh" % parent_dir

kwargs1 = {'verbose': False, 'ignoresecuredevice': False}
device, serialno = ViewClient.connectToDeviceOrExit(**kwargs1)
kwargs2 = {'startviewserver': True, 'forceviewserveruse': False,
           'autodump': False, 'ignoreuiautomatorkilled': True,
           'compresseddump': False}
vc = ViewClient(device, serialno, **kwargs2)

antutu_sum = 0


def dump_always():
    success = False
    while not success:
        try:
            vc.dump()
            success = True
        except RuntimeError:
            print("Got RuntimeError when call vc.dump()")
            time.sleep(5)
        except ValueError:
            print("Got ValueError when call vc.dump()")
            time.sleep(5)


test_items = [u'3D', u'UX', u'CPU', u'RAM']
test_subitems = {
    u'3D': [u'3D [Garden]', u'3D [Marooned]'],
    u'UX': [u'UX Data Secure', u'UX Data process', u'UX Strategy games', u'UX Image process', u'UX I/O performance'],
    u'CPU': [u'CPU Mathematics', u'CPU Common Use', u'CPU Multi-Core'],
    u'RAM': []
}


def parse_result():
    global antutu_sum

    for item in test_items:
        print("Try to find result for test suite: %s" % item)
        found_view = False
        while not found_view:
            dump_always()
            id_root = vc.findViewWithText(item)
            if id_root:
                print("Found result id_root for test suite: %s" % item)
                found_view = True
            else:
                dump_always()
                print("Press DPAD_DOWN to find %s item" % item)
                device.press('DPAD_DOWN')
                time.sleep(2)

        print("Try to find the score value for test suite:%s" % item)
        # Try to find the score for that item
        found_view = False
        while not found_view:
            dump_always()
            id_root = vc.findViewWithText(item)
            score_view = vc.findViewById("com.antutu.ABenchMark:id/tv_score_value", id_root.getParent())
            if score_view:
                score = score_view.getText().strip()
                try:
                    score = int(score)
                    call([f_output_result, "antutu6_%s" % item.upper(), 'pass', str(score), 'points'])
                    antutu_sum = antutu_sum + int(score)
                except ValueError:
                    call([f_output_result, "antutu6_%s" % item.upper(), 'fail'])

                found_view = True
                arrow_icon = vc.findViewById("com.antutu.ABenchMark:id/iv_arrow", id_root.getParent())
                if arrow_icon:
                    arrow_icon.touch()

                print("Found score value for test suite: %s: %s" % (item, score))

            else:
                print("Press DPAD_DOWN to find %s item value" % item.lower())
                device.press('DPAD_DOWN')
                time.sleep(2)

        for sub_item in test_subitems[item]:

            print("Try to find score value for sub item: %s" % sub_item)
            found_view = False
            while not found_view:
                dump_always()
                subitem_obj = vc.findViewWithText(sub_item)
                if subitem_obj:
                    subitem_value_obj = vc.findViewByIdOrRaise("com.antutu.ABenchMark:id/tv_value", subitem_obj.getParent())
                    subitem_key = sub_item.replace("[", '').replace("]", '')
                    subitem_key = subitem_key.replace("/", '')
                    subitem_score = subitem_value_obj.getText().strip()
                    try:
                        subitem_score = int(subitem_score)
                        call([f_output_result, "antutu6_%s" % subitem_key,
                              'pass', str(subitem_score), 'points'])
                    except ValueError:
                        call([f_output_result, "antutu6_%s" % subitem_key, 'fail'])

                    found_view = True
                    print("Found score value for sub itme: %s : %s" % (sub_item, subitem_score))
                else:
                    print("Press DPAD_DOWN to find sub item: %s" % sub_item)
                    device.press('DPAD_DOWN')
                    time.sleep(2)


def main():
    # Enable 64-bit
    time.sleep(10)

    finished = False
    while not finished:
        dump_always()
        test_region = vc.findViewById("com.antutu.ABenchMark:"
                                      "id/start_test_region")
        if test_region:
            test_region.touch()

        time.sleep(30)
        dump_always()
        text_qr_code = vc.findViewWithText(u'QRCode of result')
        if text_qr_code:
            finished = True
            print("Benchmark test finished!")

        stop_msg = 'Unfortunately, AnTuTu 3DBench has stopped.'
        msg_stopped = vc.findViewWithText(stop_msg)
        if msg_stopped:
            btn_ok = vc.findViewWithTextOrRaise(u'OK')
            btn_ok.touch()

        # cancel the update
        update_msg = "New update available"
        update_window = vc.findViewWithText(update_msg)
        if update_window:
            btn_cancel = vc.findViewWithTextOrRaise(u'Cancel')
            btn_cancel.touch()

        msg = "Please allow the permissions we need for test"
        need_permission_msg = vc.findViewWithText(msg)
        if need_permission_msg:
            btn_ok = vc.findViewWithTextOrRaise(u'OK')
            btn_ok.touch()

        allow_permission_btn = vc.findViewById('com.android.packageinstaller'
                                               ':id/permission_allow_button')
        if allow_permission_btn:
            allow_permission_btn.touch()

    parse_result()

    call([f_output_result, "antutu6_total", 'pass',
          str(antutu_sum), 'points'])

if __name__ == '__main__':
    main()
