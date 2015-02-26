import json
from base64 import standard_b64decode
from os import mkdir, chdir, path
from optparse import OptionParser
from random import choice
from string import ascii_uppercase
from subprocess import call


if __name__ == '__main__':
    usage = "usage: %prog -f <results file> -t <test name>"
    parser = OptionParser(usage=usage)
    parser.add_option("-f", "--file", dest="filename",
                      help="result file", metavar="FILE")
    parser.add_option("-t", "--testcase", dest="testcase",
                      help="lava-android-test test name")

    (options, args) = parser.parse_args()

    if not options.filename:
        parser.error("Results file is mandatory")
    if not options.testcase:
        parser.error("Test name is mandatory")

    source = file(options.filename, "rb")
    bundle = json.loads(source.read())

    for run in bundle['test_runs']:
        test_id = run['test_id']
        print "total number of results in %s: %s" % (test_id, len(run['test_results']))
        for index, result in enumerate(run['test_results']):
            print "TESTCASE: %s-[%s.%s] - %s (%s)" % (
                options.testcase,
                test_id.replace(" ", "_"),
                result['test_case_id'].replace(" ", "_"),
                result['result'],
                index)
        print "LAVA TEST CASE SECTION FINISHED!"
        if 'attachments' in run:
            attachments_dir_name = ''.join(choice(ascii_uppercase) for _ in range(6))
            mkdir(attachments_dir_name)
            for attachment in run['attachments']:
                print "Extracting %s to %s" % (attachment['pathname'], attachments_dir_name)
                attachment_file = open(
                    path.join(attachments_dir_name,
                              attachment['pathname']),
                    'wb')
                attachment_file.write(standard_b64decode(attachment['content']))
                attachment_file.close()
                chdir(attachments_dir_name)
                call(["lava-test-run-attach",
                      attachment['pathname'],
                      attachment['mime_type']])
                chdir("..")
