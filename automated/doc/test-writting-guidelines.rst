=======================
Test Writing Guidelines
=======================

This document describes guidelines and is intended for anybody who want to write
or modify a test case. It's not a definitive guide and it's not, by any means, a
substitute for common sense.

General Rules
=============

1. Simplicity
-------------

It's worth keep test cases as simple as possible.

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
Easy-to-read version of PEP 8 available at `pep8.org <pep8.org>`_

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

Tests are generally placed under 'linux/' directory. Everything that related to
the test goes under the same folder named with test case name.

Define 'linux/test-case-name/output' folder in test case to save test output and
result. Using a dedicated folder is helpful to distinguish between test script
and test output.

2. Installing dependence
~~~~~~~~~~~~~~~~~~~~~~~~

The same test case should support Debian/Ubuntu, Fedora/CentOS and OE builds.

When using package management tool like apt or yum/dnf to install dependencies,
package name may vary depending on the distributions you want to support, so you
will need to define dependent packages by distribution. dist_name and
install_deps functions provided in 'lib/sh-test-lib' can be used to detect the
distribution at running time and handle package installation respectively.

On OSes built using OpenEmbedded that don't support installing additional
packages, even compile and install from source code is impossible when tool
chain isn't available. The required dependencies should be pre-install. To run
test case that contain install steps on this kind of OS:

    * Define 'SKIP_INSTALL' variable with 'False' as default.
    * Add parameter '-s <True|False>', so that user can modify 'SKIP_INSTALL'.
    * Use "install_deps ${pkgs} ${SKIP_INSTALL}" to install package. It will
      check the value of 'SKIP_INSTALL' to determine whether skip the install.
    * When you have customized install steps like code downloading, compilation
      and install defined, you will need to do the check yourself.

An example::

    dist_name
    case "${dist}" in
      Debian|Ubuntu) pkgs="lsb-release" ;;
      Fedora|CentOS) pkgs="redhat-lsb-core" ;;
    esac
    install_deps "${pkgs}" "${SKIP_INSTALL}"

3. Saving output
~~~~~~~~~~~~~~~~~

'test-case-name/output' directory is recommended to save test log and result
files.

4. Parsing result
~~~~~~~~~~~~~~~~~

Saving parsed result in the same format is important for post process such as
sending to LAVA. The following result format should be followed.

    test-caes-id pass/fail/skip
    test-case-id pass/fail/skip measurement units

'output/result.txt' file is recommended to save result.

We encourage test writer to use the functions defined in 'sh-test-lib' to format
test result.

Print "test-case pass/fail" by checking exit code::

    check_return "${test_case_id}"

Add a metric for performance test::

    add_metic "${test-case-id}" "pass/fail/skip" "${measurement}" "${units"}


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
