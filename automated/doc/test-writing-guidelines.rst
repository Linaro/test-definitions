=======================
Test Writing Guidelines
=======================

This document describes guidelines and is intended for anybody who wants to write
or modify a test case. It's not a definitive guide and it's not, by any means, a
substitute for common sense.

General Rules
=============

1. Simplicity
-------------

It's worth keeping test cases as simple as possible.

2. Code duplication
-------------------

Whenever you are about to copy a large part of the code from one test case to
another, think if it is possible to move it to a library to reduce code
duplication and the cost of maintenance.

3. Coding style
---------------

Use common sense and BE CONSISTENT.

If you are editing code, take a few minutes to look at the code around you and
determine its style.

The point of having style guidelines is to have a common vocabulary of coding so
people can concentrate on what you are saying, rather than on how you are saying
it.

3.1 Shell coding style
~~~~~~~~~~~~~~~~~~~~~~
When writing test cases in shell write in *portable shell* only.

You can either try to run the test cases on Debian which has '/bin/sh' pointing
to 'dash' by default or install 'dash' on your favorite distribution and use
it to run the tests.

Ref: `Shell Style Guide <https://google.github.io/styleguide/shell.xml>`_

3.2 Python coding style
~~~~~~~~~~~~~~~~~~~~~~~
Please follow PEP 8 style guide whenever possible.

Ref: `PEP 8 <https://www.python.org/dev/peps/pep-0008/>`_
Easy-to-read version of PEP 8 available at `pep8.org <http://pep8.org>`_

4. Commenting code
------------------

Use useful comments in your program to explain:

    * assumptions
    * important decisions
    * important details
    * problems you're trying to solve
    * problems you're trying to overcome in your program, etc.

Code tells you how, comments should tell you why.

5. License
----------
Code contributed to this repository should be licensed under GPLv2+ (GNU GPL
version 2 or any later version).

Writing a test case
===================

Linux
------

1. Structure
~~~~~~~~~~~~

Tests are generally placed under 'linux/' directory. Everything that relates to
the test goes under the same folder named with test case name.

Define 'linux/test-case-name/output' folder in test case to save test output and
result. Using a dedicated folder is helpful to distinguish between test script
and test output.

2. Installing dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~

The same test case should work on Debian/Ubuntu, Fedora/CentOS and OE based
distributions whenever possible. This can be achieved with install_deps()
function. The following is a simple example. "${SKIP_INSTALL}" should be set to
'true' on distributions that do not supported install_deps(). In the unsupported
case, if "${SKIP_INSTALL}" is 'true', install_deps() still will skip package
installation.

Example 1::

    install_deps "${pkgs}" "${SKIP_INSTALL}"

Package name may vary by distribution. In this case, you will need to handle
package installation with separate lines. dist_name() function is designed to
detect the distribution ID at running time so that you can define package name
by distribution. Refer to the following example.

Example 2::

    dist_name
    case "${dist}" in
      debian|ubuntu) install_deps "lsb-release" "${SKIP_INSTALL}" ;;
      fedora|centos) install_deps "redhat-lsb-core" "${SKIP_INSTALL}" ;;
      *) warn_msg "Unsupported distro: ${dist}! Package installation skipped." ;;
    esac

Except automated package installation, you may also need to download and install
software manually. If you want to make these steps skippable, here is an
example.

Example 3::

    if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
        dist_name
        case "${dist}" in
            debian|ubuntu) install_deps "${pkgs}" ;;
            fedora|centos) install_deps "${pkgs}" ;;
            *) warn_msg "Unsupported distro: ${dist}! Package installation skipped." ;;
        esac

        # manually install steps.
        git clone "${repo}"
        cd "${dir}"
        ./configure && make install
    fi

Hopefully, the above 3 examples cover most of the user cases. When
writing test cases, in general:

    * Define 'SKIP_INSTALL' variable with 'false' as default.
    * Add parameter '-s <True|False>', so that user can modify 'SKIP_INSTALL'.
    * Try to use the above functions, and give unknown distributions more care.

3. Saving output
~~~~~~~~~~~~~~~~~

'test-case-name/output' directory is recommended to save test log and result
files.

4. Parsing result
~~~~~~~~~~~~~~~~~

Saving parsed result in the same format is important for post process such as
sending to LAVA. The following result format should be followed.

    test-caes-id pass/fail/skip
    test-case-id pass/fail/skip measurement
    test-case-id pass/fail/skip measurement units

'output/result.txt' file is recommended to save result.

We encourage test writers to use the functions defined in 'sh-test-lib' to format
test result.

Print "test-case pass/fail" by checking exit code::

    check_return "${test_case_id}"

Add a metric for performance test::

    add_metic "${test-case-id}" "pass/fail/skip" "${measurement}" "${units}"


5. Running in LAVA
~~~~~~~~~~~~~~~~~~

LAVA is the foundation of test automation in Linaro. It is able to handle image
deployment and boot, and provides a test shell for test run. To run a test case
in LAVA, a definition file in YAML format is required.

Bear in mind, do all the LAVA-specific steps in test definition file, and do not
use any LAVA-specific steps in test script, otherwise you may lock yourself out
of your own test case when LAVA isn't available or the board you want to test
wasn't deployed in LAVA.

Test script should handle dependencies installation, test execution, result
parsing and other work in a self-contained way, and produce result.txt file with
a format that can be easily parsed and sent to LAVA. This is a more robust way.
Test case works with/without LAVA and can be tested locally.

A general test definition file should contain the below keywords and steps::

    metadata:
    # Define parameters required by test case with default values.
    params:
      SKIP_INSTALL: False
    run:
      # A typical test run in LAVA requires the below steps.
      steps:
        # Enter the directory of the test case.
        - cd ./automated/linux/smoke/
        # Run the test.
        - ./smoke.sh -s "${SKIP_INSTALL}"
        # Send the results in result.txt to LAVA.
        - ../../utils/send-to-lava.sh ./output/result.txt

Android specific
----------------

The above test writing guidelines also apply to Android test cases. The major
difference is that we run all Android test cases through adb shell. Compare with
local run, adb and adb shell enable us to do more. And this model is well
supported by LAVA V2 LXC protocol.

A typical Android test case can be written with the following steps::

    # Check adb connect with initialize_adb funtion
    initialize_adb
    # Install binaries and scripts
    detect_abi
    install "../../bin/${abi}/busybox"
    install "./device-script.sh"
    # Run test script through adb shell.
    adb -s "${SN}" shell device-script.sh
    # Pull output from device for parsing.
    pull_output "${DEVICE_OUTPUT}" "${HOST_OUTPUT}"


6. Using test-runner
~~~~~~~~~~~~~~~~~~~~

Using test-runner to run tests locally
--------------------------------------

The tests can be run directly on the board, assuming you have installed basic
tools such as git, gcc, ... `test-runner` is written in Python and requires
`pexpect` and `yaml` modules to be installed as well. To run tests directly
on the board, get a prompt and run::

    git clone http://git.linaro.org/qa/test-definitions.git
    cd test-definitions
    source automated/bin/setenv.sh
    test-runner -p plans/rpb_ee/rpb_ee_functional.yaml

By default the test output are stored in `$HOME/output/`, and the output folder
can be configured with `-o` argument.

Using test-runner to run tests from host PC
-------------------------------------------

It is also possible to run tests from a host PC if the board is available on
the network. In that case `test-runner` will connect to the board over SSH, and
you need to setup the board so that the host PC can connect to the board over
SSH without any prompt (password less connection). To run from the host, run
the following commands from the host command prompt::

    git clone http://git.linaro.org/qa/test-definitions.git
    cd test-definitions
    source automated/bin/setenv.sh
    test-runner -g root@ip -p plans/rpb_ee/rpb_ee_functional.yaml

Where `root@ip` is the credential to connect to the board over SSH.

By default the test output are stored in `$HOME/output/root@ip`, and the output
folder can be configured with `-o` argument.

Running individual tests
------------------------

Instead of running a test plan with `-p` argument, it is possible to run a single
test only using `-d` argument.

Test output
-----------

At the end of the test run, the following artefact are available in the output
folder:

    - `result.csv` and `result.json` which contain summary of test results
      (including test name, test case ID, test results such as pass, fail, skip,
      test measurement, if any, with the associated measurement unit, and the test
      argument used
    - For each test executed, there is a folder which contains the console output
      of the test run, `stdout.log` as well as all test scripts/data

Test Contribution Checklist
===========================

* When applicable, check test cases with the following tools with line length
  rule relaxed.

    - checkbashisms - check for bashisms in /bin/sh scripts.
    - shellcheck - Shell script analysis tool.
    - pep8 - check Python code against the style conventions in PEP 8.
    - pyflakes - simple Python 2 source checker
    - pylint - code analysis for Python

* Run test cases on local system without LAVA.
* Optionally, run test cases in LAVA and provide job example.
