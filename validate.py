#!/usr/bin/python3
import argparse
import os
import sys
import subprocess
import traceback
import yaml

run_pep8 = False
try:
    import pep8
    run_pep8 = True
except:
    print("PEP8 is not available!")


def print_stderr(message):
    sys.stderr.write(message)
    sys.stderr.write("\n")


def publish_result(result_message_list, args):
    result_message = '\n'.join(result_message_list)
    try:
        f = open(args.result_file, 'a')
        f.write("\n\n")
        f.write(result_message)
        f.write("\n\n")
        f.close()
    except IOError as e:
        print_stderr("Cannot write to result file: %s" % args.result_file)
    print_stderr(result_message)


def pep8_check(filepath, args):
    _fmt = "%(row)d:%(col)d: %(code)s %(text)s"
    options = {
        'ignore': args.pep8_ignore,
        "show_source": True}
    pep8_checker = pep8.StyleGuide(options)
    fchecker = pep8_checker.checker_class(
        filepath,
        options=pep8_checker.options)
    fchecker.check_all()
    if fchecker.report.file_errors > 0:
        result_message_list = []
        result_message_list.append("* PEP8: [FAILED]: " + filepath)
        fchecker.report.print_statistics()
        for line_number, offset, code, text, doc in fchecker.report._deferred_print:
            result_message_list.append(
                _fmt % {
                    'path': filepath,
                    'row': fchecker.report.line_offset + line_number,
                    'col': offset + 1,
                    'code': code, 'text': text,
                })
        publish_result(result_message_list, args)
        return 1
    else:
        message = "* PEP8: [PASSED]: " + filepath
        print_stderr(message)
    return 0


def metadata_check(filepath, args):
    if filepath.lower().endswith("yaml"):
        with open(filepath, "r") as f:
            result_message_list = []
            y = yaml.load(f.read())
            if 'metadata' not in y.keys():
                result_message_list.append("* METADATA [FAILED]: " + filepath)
                result_message_list.append("\tmetadata section missing")
                publish_result(result_message_list, args)
                exit(1)
            metadata_dict = y['metadata']
            mandatory_keys = set([
                'name',
                'format',
                'description',
                'maintainer',
                'os',
                'devices'])
            if not mandatory_keys.issubset(set(metadata_dict.keys())):
                result_message_list.append("* METADATA [FAILED]: " + filepath)
                result_message_list.append("\tmandatory keys missing: %s" %
                                           mandatory_keys.difference(set(metadata_dict.keys())))
                result_message_list.append("\tactual keys present: %s" %
                                           metadata_dict.keys())
                publish_result(result_message_list, args)
                return 1
            for key in mandatory_keys:
                if len(metadata_dict[key]) == 0:
                    result_message_list.append("* METADATA [FAILED]: " + filepath)
                    result_message_list.append("\t%s has no content" % key)
                    publish_result(result_message_list, args)
                    return 1
            result_message_list.append("* METADATA [PASSED]: " + filepath)
            publish_result(result_message_list, args)
    return 0


def validate_yaml(filename, args):
    with open(filename, "r") as f:
        try:
            y = yaml.load(f.read())
            message = "* YAMLVALID: [PASSED]: " + filename
            print_stderr(message)
        except:
            message = "* YAMLVALID: [FAILED]: " + filename
            result_message_list = []
            result_message_list.append(message)
            result_message_list.append("\n\n")
            exc_type, exc_value, exc_traceback = sys.exc_info()
            for line in traceback.format_exception_only(exc_type, exc_value):
                result_message_list.append(' ' + line)
            publish_result(result_message_list, args)
            return 1
    return 0


def validate_shell(filename, ignore_options):
    ignore_string = ""
    if args.shellcheck_ignore is not None:
        ignore_string = "-e %s" % " ".join(args.shellcheck_ignore)
    if len(ignore_string) < 4:  # contains only "-e "
        ignore_string = ""
    cmd = 'shellcheck %s' % ignore_string
    return validate_external(cmd, filename, "SHELLCHECK", args)


def validate_php(filename, args):
    cmd = 'php -l'
    return validate_external(cmd, filename, "PHPLINT", args)


def validate_external(cmd, filename, prefix, args):
    final_cmd = "%s %s 2>&1" % (cmd, filename)
    status, output = subprocess.getstatusoutput(final_cmd)
    if status == 0:
        message = '* %s: [PASSED]: %s' % (prefix, filename)
        print_stderr(message)
    else:
        result_message_list = []
        result_message_list.append('* %s: [FAILED]: %s' % (prefix, filename))
        result_message_list.append('* %s: [OUTPUT]:' % prefix)
        for line in output.splitlines():
            result_message_list.append(' ' + line)
        publish_result(result_message_list, args)
        return 1
    return 0


def validate_file(args, path):
    exitcode = 0
    if path.endswith(".yaml"):
        exitcode = validate_yaml(path, args)
        if exitcode == 0:
            # if yaml isn't valid there is no point in checking metadata
            exitcode = metadata_check(path, args)
    elif run_pep8 and path.endswith(".py"):
        exitcode = pep8_check(path, args)
    elif path.endswith(".php"):
        exitcode = validate_php(path, args)
    elif path.endswith(".sh") or \
            path.endswith("sh-test-lib") or \
            path.endswith("android-test-lib"):
        exitcode = validate_shell(path, args)
    return exitcode


def run_unit_tests(args, filelist=None):
    exitcode = 0
    if filelist is not None:
        for filename in filelist:
            tmp_exitcode = validate_file(args, filename)
            if tmp_exitcode != 0:
                exitcode = 1
    else:
        for root, dirs, files in os.walk('.'):
            if not root.startswith("./.git"):
                for name in files:
                    tmp_exitcode = validate_file(
                        args,
                        root + "/" + name)
                    if tmp_exitcode != 0:
                        exitcode = 1
    return exitcode


def main(args):
    exitcode = 0
    if args.git_latest:
        # check if git exists
        git_status, git_result = subprocess.getstatusoutput(
            "git show --name-only --format=''")
        if git_status == 0:
            filelist = git_result.split()
            exitcode = run_unit_tests(args, filelist)
    elif len(args.file_path) > 0:
        exitcode = run_unit_tests(args, [args.file_path])
    else:
        exitcode = run_unit_tests(args)
    exit(exitcode)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-p",
                        "--pep8-ignore",
                        nargs="*",
                        default=["E501"],
                        help="Space separated list of pep8 exclusions",
                        dest="pep8_ignore")
    parser.add_argument("-s",
                        "--shellcheck-ignore",
                        nargs="*",
                        help="Space separated list of shellcheck exclusions",
                        dest="shellcheck_ignore")
    parser.add_argument("-g",
                        "--git-latest",
                        action="store_true",
                        default=False,
                        help="If set, the script will try to evaluate files in last git \
                            commit instead of the whole repository",
                        dest="git_latest")
    parser.add_argument("-f",
                        "--file-path",
                        default="",
                        help="Path to the file that should be checked",
                        dest="file_path")
    parser.add_argument("-r",
                        "--result-file",
                        default="build-error.txt",
                        help="Path to the file that contains results in case of failure",
                        dest="result_file")

    args = parser.parse_args()
    main(args)
