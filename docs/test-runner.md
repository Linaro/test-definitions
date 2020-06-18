# Test Runner

## Installation
Installing the latest development version:

    git clone https://github.com/Linaro/test-definitions
    cd ./test-definitions
    . ./automated/bin/setenv.sh
    pip install -r ${REPO_PATH}/automated/utils/requirements.txt

If the above succeeds, try:

    test-runner -h

### Using virtualenv
test-runner can also be installed inside virtualenv if one doesn't wish
to install directly on the system. This might be useful for hacking the tool
or the tests themselves.

    git clone https://github.com/Linaro/test-definitions
    cd ./test-definitions
    . ./automated/bin/setenv.sh
    virtualenv -p python3 venv
    . ./venv/bin/activate
    pip install -r ${REPO_PATH}/automated/utils/requirements.txt

If the above succeeds, try:

    test-runner -h

## Running automated tests
test-runner can be used to execute automated tests on the local or remote
target.

### Running tests on the local target (cheating a bit)
Running tests on local target might be tricky. By default test-runner
requires to be executed as root. This limitation is lifted for manual tests.
Passing *--kind manual* will result in test execution without root access.
This only works if there is no need to install dependencies, so *--skip_install*
is also required.

    test-runner --kind manual --test_def automated/linux/smoke/smoke.yaml --skip_install

### Running tests over ssh
test-runner can connect to the target using ssh. It requires passwordless
authentication. This means that:
 * sshd on the target must accept certificate based authentication
 * user's public key needs to be added to root's authorized_keys on the target

#### ssh setup
1. make sure sshd accepts passwordless connection. Content of /etc/sshd_config
   ```
   PubkeyAuthentication yes
   AuthorizedKeysFile .ssh/authorized_keys
   ```

2. Copy your public key to /root/.ssh/authorized_keys. Public key is usually located
   at ~/.ssh/id_rsa.pub

#### Executing tests remotely

    test-runner --target root@192.168.0.44 --test_def automated/linux/smoke/smoke.yaml

### Running a test plan

Run a set of tests defined in agenda file:

    test-runner -p ./plans/linux-example.yaml

Apply test plan overlay to skip, amend or add tests:

    test-runner -p ./plans/linux-example.yaml -O test-plan-overlay-example.yaml


## Running manual tests
test-runner also allows to execute and record results for manual tests.
It has a built-in simple shell for test execution.

```
2020-06-18 10:15:03,619 - RUNNER: INFO: Tests to run:
{'path': 'manual/generic/kernel-version.yaml', 'uuid': '4ce9c17b-52f6-4eb9-8804-278d6191b454', 'timeout': None, 'skip_install': False}
2020-06-18 10:15:07,482 - RUNNER.TestSetup: INFO: Test repo copied to: /home/milosz/output/kernel-version_4ce9c17b-52f6-4eb9-8804-278d6191b454
kernel-version

        Welcome to manual test executor. Type 'help' for available commands.
        This shell is meant to be executed on your computer, not on the system
        under test. Please execute the steps from the test case, compare to
        expected result and record the test result as 'pass' or 'fail'. If there
        is an issue that prevents from executing the step, please record the result
        as 'skip'.

linux-kernel-version > help

Documented commands (type help <topic>):
========================================
EOF      description  fail  next  quit  start
current  expected     help  pass  skip  steps

linux-kernel-version > description
Test if the kernel version is correct
linux-kernel-version > steps
0. uname -a
1. Check the output of the kernel version matches the version displayed on the build page
linux-kernel-version > expected
0. Kernel version matches the version on build page
linux-kernel-version > current
0. uname -a
linux-kernel-version > next
1. Check the output of the kernel version matches the version displayed on the build page
linux-kernel-version > pass
Recording pass in /home/milosz/output/kernel-version_4ce9c17b-52f6-4eb9-8804-278d6191b454/stdout.log
2020-06-18 10:16:06,439 - RUNNER.ResultParser: WARNING: All parameters for qa reports are not set, results will not be pushed to qa reports
2020-06-18 10:16:06,439 - RUNNER.ResultParser: INFO: Result files saved to: /home/milosz/output/kernel-version_4ce9c17b-52f6-4eb9-8804-278d6191b454
--- Printing result.csv ---
name,test_case_id,result,measurement,units,test_params
linux-kernel-version,linux-kernel-version,pass,,,
```

### Running single test

    test-runner --test_def manual/generic/kernel-version.yaml --kind manual

## Executing manual tests from test plan
When test plan contains manual tests, test-runned will execute them one-by-one
in the built-in shell. Results will be recorder the same way as for automated tests

    test-runner --test_plan plans/linux-test-plan-example.yaml --kind manual


## Collecting result

## Using test-runner
test-runner needs a separate directory outside the repo to store test and result files.
The directory defaults to `$HOME/output` and can be changed with `-o <dir>`. test-runner
converts test definition file to `run.sh` and then parses its stdout. Results
will be saved to results.{json,csv} by test. e.g.

    /root/output/smoke_9879e7fd-a8b6-472d-b266-a20b05d52ed1/result.csv

When using the same output directory for multiple tests, test-runner combines results
from all tests and save them to `${OUTPUT}/results.{json,csv}`. e.g.

    /root/output/result.json

### Exporting test results to SQUAD (aka qa-reports)
test-runner is now able to upload test results to SQUAD. Example below:

    test-runner --test_def manual/generic/kernel-version.yaml \
        --kind manual \
        --qa-reports-server https://staging-qa-reports.linaro.org \
        --qa-reports-project mwasilew-example \
        --qa-reports-group people \
        --qa-reports-env laptop \
        --qa-reports-build-version 1 \
        --qa-reports-token ${token}

#### SQUAD metadata
test-runner can also submit metadata as part of the results. Metadata is
usually used to describe the versions of software under test and test suites.
Following options for metadata upload are available:

```
--qa-reports-disable-metadata
                    Disable sending metadata to SQUAD. Default: false
--qa-reports-metadata KEY=VALUE [KEY=VALUE ...]
                    List of metadata key=value pairs to be sent to SQUAD
--qa-reports-metadata-file QA_REPORTS_METADATA_FILE
                    YAML file that defines metadata to be reported to SQUAD
```

Metadata file should be of format:
```
key1: value1
key2: value2
```
