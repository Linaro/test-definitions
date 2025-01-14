#!/usr/bin/python3
import argparse
import os
import sys
import subprocess
import traceback
import yaml

run_pycodestyle = False
try:
    import pycodestyle

    run_pycodestyle = True
except ImportError as e:
    print(e)
    print("Install pycodestyle: pip3 install pycodestyle")
    sys.exit(1)

try:
    import magic
except ImportError as e:
    print(e)
    print("Install python-magic: pip3 install python-magic")
    sys.exit(1)


def print_stderr(message):
    sys.stderr.write(message)
    sys.stderr.write("\n")


def publish_result(result_message_list, args):
    if result_message_list:
        result_message = "\n".join(result_message_list)
        try:
            f = open(args.result_file, "a")
            f.write(result_message)
            f.write("\n")
            f.close()
        except IOError as e:
            print(e)
            print_stderr("Cannot write to result file: %s" % args.result_file)
        if args.verbose:
            print_stderr(result_message)
    else:
        result_message = "\n".join(args.failed_message_list)
        print_stderr(result_message)


def detect_abi():
    # Retrieve the current canonical abi from
    # automated/lib/sh-test-lib:detect_abi
    return (
        subprocess.check_output(
            ". automated/lib/sh-test-lib && detect_abi && echo $abi", shell=True
        )
        .decode("utf-8")
        .strip()
    )


def pycodestyle_check(filepath, args):
    _fmt = "%(row)d:%(col)d: %(code)s %(text)s"
    options = {"ignore": args.pycodestyle_ignore, "show_source": True}
    pycodestyle_checker = pycodestyle.StyleGuide(options)
    fchecker = pycodestyle_checker.checker_class(
        filepath, options=pycodestyle_checker.options
    )
    fchecker.check_all()
    if fchecker.report.file_errors > 0:
        result_message_list = []
        result_message_list.append("* PYCODESTYLE: [FAILED]: " + filepath)
        fchecker.report.print_statistics()
        for line_number, offset, code, text, doc in fchecker.report._deferred_print:
            result_message_list.append(
                _fmt
                % {
                    "path": filepath,
                    "row": fchecker.report.line_offset + line_number,
                    "col": offset + 1,
                    "code": code,
                    "text": text,
                }
            )
        publish_result(result_message_list, args)
        args.failed_message_list = args.failed_message_list + result_message_list
        return 1
    else:
        if args.verbose:
            message = "* PYCODESTYLE: [PASSED]: " + filepath
            print_stderr(message)
    return 0


def validate_yaml_contents(filepath, args):
    def validate_testdef_yaml(y, args):
        result_message_list = []
        if "metadata" not in y.keys():
            result_message_list.append("* METADATA [FAILED]: " + filepath)
            result_message_list.append("\tmetadata section missing")
            publish_result(result_message_list, args)
            args.failed_message_list = args.failed_message_list + result_message_list
            exit(1)
        metadata_dict = y["metadata"]
        mandatory_keys = set(
            ["name", "format", "description", "maintainer", "os", "devices"]
        )
        if not mandatory_keys.issubset(set(metadata_dict.keys())):
            result_message_list.append("* METADATA [FAILED]: " + filepath)
            result_message_list.append(
                "\tmandatory keys missing: %s"
                % mandatory_keys.difference(set(metadata_dict.keys()))
            )
            result_message_list.append(
                "\tactual keys present: %s" % metadata_dict.keys()
            )
            publish_result(result_message_list, args)
            args.failed_message_list = args.failed_message_list + result_message_list
            return 1
        for key in mandatory_keys:
            if len(metadata_dict[key]) == 0:
                result_message_list.append("* METADATA [FAILED]: " + filepath)
                result_message_list.append("\t%s has no content" % key)
                publish_result(result_message_list, args)
                args.failed_message_list = (
                    args.failed_message_list + result_message_list
                )
                return 1
        # check if name has white spaces
        if metadata_dict["name"].find(" ") > -1:
            result_message_list.append("* METADATA [FAILED]: " + filepath)
            result_message_list.append("\t'name' contains whitespace")
            publish_result(result_message_list, args)
            args.failed_message_list = args.failed_message_list + result_message_list
            return 1
        # check 'format' value
        if metadata_dict["format"] not in [
            "Lava-Test Test Definition 1.0",
            "Manual Test Definition 1.0",
        ]:
            result_message_list.append("* METADATA [FAILED]: " + filepath)
            result_message_list.append("\t'format' has incorrect value")
            publish_result(result_message_list, args)
            args.failed_message_list = args.failed_message_list + result_message_list
            return 1

        result_message_list.append("* METADATA [PASSED]: " + filepath)
        publish_result(result_message_list, args)
        return 0

    def validate_skipgen_yaml(filepath, args):
        abi = detect_abi()
        # Run skipgen on skipgen yaml file to check for output and errors
        skips = (
            subprocess.check_output(
                "automated/bin/{}/skipgen {}".format(abi, filepath), shell=True
            )
            .decode("utf-8")
            .strip()
        )
        if len(skips.split("\n")) < 1:
            message = "* SKIPGEN [FAILED]: " + filepath + " - No skips found"
            publish_result([message], args)
            args.failed_message_list.append(message)
            return 1
        publish_result(["* SKIPGEN [PASSED]: " + filepath], args)
        return 0

    filecontent = None
    try:
        with open(filepath, "r") as f:
            filecontent = f.read()
    except FileNotFoundError:
        publish_result(
            ["* YAMLVALIDCONTENTS [PASSED]: " + filepath + " - deleted"], args
        )
        return 0
    y = yaml.load(filecontent, Loader=yaml.FullLoader)
    if "run" in y.keys():
        # test definition yaml file
        return validate_testdef_yaml(y, args)
    elif "skiplist" in y.keys():
        # skipgen yaml file
        return validate_skipgen_yaml(filepath, args)
    else:
        publish_result(
            [
                "* YAMLVALIDCONTENTS [SKIPPED]: "
                + filepath
                + " - Unknown yaml type detected"
            ],
            args,
        )
        return 0


def validate_yaml(filename, args):
    filecontent = None
    try:
        with open(filename, "r") as f:
            filecontent = f.read()
    except FileNotFoundError:
        publish_result(["* YAMLVALID [PASSED]: " + filename + " - deleted"], args)
        return 0
    try:
        yaml.load(filecontent, Loader=yaml.FullLoader)
        if args.verbose:
            message = "* YAMLVALID: [PASSED]: " + filename
            print_stderr(message)
    except yaml.YAMLError:
        message = "* YAMLVALID: [FAILED]: " + filename
        result_message_list = []
        result_message_list.append(message)
        result_message_list.append("\n\n")
        exc_type, exc_value, exc_traceback = sys.exc_info()
        for line in traceback.format_exception_only(exc_type, exc_value):
            result_message_list.append(" " + line)
        publish_result(result_message_list, args)
        args.failed_message_list = args.failed_message_list + result_message_list
        return 1
    return 0


def validate_shell(filename, args):
    ignore_string = ""
    if args.shellcheck_ignore is not None:
        # Exclude types of warnings in the following format:
        # -e CODE1,CODE2..
        ignore_string = "-e %s" % ",".join(args.shellcheck_ignore)
    if len(ignore_string) < 4:  # contains only "-e "
        ignore_string = ""
    ignore_string = "-S %s %s" % (args.shellcheck_level, ignore_string)
    cmd = "shellcheck %s" % ignore_string
    return validate_external(cmd, filename, "SHELLCHECK", args)


def validate_php(filename, args):
    cmd = "php -l"
    return validate_external(cmd, filename, "PHPLINT", args)


def validate_external(cmd, filename, prefix, args):
    final_cmd = "%s %s 2>&1" % (cmd, filename)
    status, output = subprocess.getstatusoutput(final_cmd)
    if status == 0:
        message = "* %s: [PASSED]: %s" % (prefix, filename)
        publish_result([message], args)
    else:
        result_message_list = []
        result_message_list.append("* %s: [FAILED]: %s" % (prefix, filename))
        result_message_list.append("* %s: [OUTPUT]:" % prefix)
        for line in output.splitlines():
            result_message_list.append(" " + line)
        publish_result(result_message_list, args)
        args.failed_message_list = args.failed_message_list + result_message_list
        return 1
    return 0


def validate_file(args, path):
    if args.verbose:
        print("Validating file: %s" % path)
    filetype = magic.from_file(path, mime=True)
    exitcode = 0
    # libmagic takes yaml as 'text/plain', so use file extension here.
    if path.endswith((".yaml", ".yml")):
        exitcode = validate_yaml(path, args)
        if exitcode == 0:
            # if yaml isn't valid there is no point in checking metadata
            exitcode = validate_yaml_contents(path, args)
    elif run_pycodestyle and filetype == "text/x-python":
        exitcode = pycodestyle_check(path, args)
    elif filetype == "text/x-php":
        exitcode = validate_php(path, args)
    elif path.endswith(".sh") or filetype == "text/x-shellscript":
        exitcode = validate_shell(path, args)
    else:
        publish_result(
            [
                "* UNKNOWN [SKIPPED]: "
                + path
                + " - Unknown file type detected: "
                + filetype
            ],
            args,
        )
        return 0
    return exitcode


def run_unit_tests(args, filelist=None):
    exitcode = 0
    if filelist is not None:
        for filename in filelist:
            tmp_exitcode = validate_file(args, filename)
            if tmp_exitcode != 0:
                exitcode = 1
    else:
        for root, dirs, files in os.walk("."):
            if not root.startswith("./.git"):
                for name in files:
                    tmp_exitcode = validate_file(args, root + "/" + name)
                    if tmp_exitcode != 0:
                        exitcode = 1
    return exitcode


def main(args):
    exitcode = 0
    if args.git_latest:
        # check if git exists
        git_status, git_result = subprocess.getstatusoutput(
            "git diff --name-only HEAD~1"
        )
        if git_status == 0:
            filelist = git_result.split()
            exitcode = run_unit_tests(args, filelist)
    elif len(args.file_path) > 0:
        exitcode = run_unit_tests(args, [args.file_path])
    else:
        exitcode = run_unit_tests(args)
    if not args.verbose:
        publish_result(None, args)
    exit(exitcode)


if __name__ == "__main__":
    failed_message_list = []
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-p",
        "--pycodestyle-ignore",
        nargs="*",
        default=["E501"],
        help="Space separated list of pycodestyle exclusions",
        dest="pycodestyle_ignore",
    )
    parser.add_argument(
        "-s",
        "--shellcheck-ignore",
        nargs="*",
        help="Space separated list of shellcheck exclusions",
        dest="shellcheck_ignore",
    )
    parser.add_argument(
        "-l",
        "--shellcheck-level",
        default="warning",
        help="Shellcheck level set with -S",
        dest="shellcheck_level",
    )

    parser.add_argument(
        "-g",
        "--git-latest",
        action="store_true",
        default=False,
        help="If set, the script will try to evaluate files in last git \
                            commit instead of the whole repository",
        dest="git_latest",
    )
    parser.add_argument(
        "-f",
        "--file-path",
        default="",
        help="Path to the file that should be checked",
        dest="file_path",
    )
    parser.add_argument(
        "-r",
        "--result-file",
        default="build-error.txt",
        help="Path to the file that contains results in case of failure",
        dest="result_file",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        default=False,
        help="Make output more verbose",
        dest="verbose",
    )

    args = parser.parse_args()
    setattr(args, "failed_message_list", failed_message_list)
    main(args)
