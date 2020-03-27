# Test Definitions
A test suite works with and without [LAVA](http://lavasoftware.org/). The following two
sets of automated tests are supported.

- `automated/linux/`
- `automated/android/`

For each test case, both the test script and the corresponding test definition files are
provided in the same folder and are named after the test case name. Test scripts are
self-contained and work independently. Test definition files in YAML format are provided
for test runs with local test-runner and within LAVA.

## Installation
Installing the latest development version:

    git clone https://github.com/Linaro/test-definitions
    cd ./test-definitions
    . ./automated/bin/setenv.sh
    pip install -r ${REPO_PATH}/automated/utils/requirements.txt

If the above succeeds, try:

    test-runner -h

## Running test
### Running test script
#### linux

    cd ./automated/linux/smoke/
    ./smoke.sh

Skip package installation:

    ./smoke.sh -s true

#### android

    cd ./automated/android/dd-wr-speed/
    ./dd-wr-speed.sh

Specify SN when more than one device connected:

    ./dd-wr-speed.sh -s "serial_no"

Specify other params:

    ./dd-wr-speed.sh -i "10" -p "/dev/block/mmcblk1p1"

### Using test-runner
#### single test run

    test-runner -d ./automated/linux/smoke/smoke.yaml

skip package install:

    test-runner -d ./automated/linux/smoke/smoke.yaml -s

#### running test plan

Run a set of tests defined in agenda file:

    test-runner -p ./plans/linux-example.yaml

Apply test plan overlay to skip, amend or add tests:

    test-runner -p ./plans/linux-example.yaml -O test-plan-overlay-example.yaml

## Collecting result

### Using test script
Test script normally puts test log and parsed results to its own `output` directory. e.g.

    automated/linux/smoke/output

### Using test-runner
test-runner needs a separate directory outside the repo to store test and result files.
The directory defaults to `$HOME/output` and can be changed with `-o <dir>`. test-runner
converts test definition file to `run.sh` and then parses its stdout. Results
will be saved to results.{json,csv} by test. e.g.

    /root/output/smoke_9879e7fd-a8b6-472d-b266-a20b05d52ed1/result.csv

When using the same output directory for multiple tests, test-runner combines results
from all tests and save them to `${OUTPUT}/results.{json,csv}`. e.g.

    /root/output/result.json

## Generating documentation

[Full docs](https://test-definitions.readthedocs.io) are generated from existing
YAML files. Resulting markdown files are not stored in the repository. In order
to generate documentation locally one needs to follow the steps below:

1. create and activate virtualenv  
   ```
   virtualenv -p python3 venv
   source venv/bin/activate
   ```
2. install requirements  
   ```
   pip install -r mkdocs_plugin/requirements.txt
   ```
3. run mkdocs
    * local http server  
      ```
      mkdocs serve
      ```  
      This will start small http server on http://127.0.0.1:8000

    * build static docs  
      ```
      mkdocs build
      ```  
      This will convert all generated markdown files to HTML files. By default
      files are stored in 'site' directory. See [mkdocs documentation](https://www.mkdocs.org/#building-the-site)
      for more details.

## Contributing

Please use Github for pull requests: https://github.com/Linaro/test-definitions/pulls

https://git.linaro.org/qa/test-definitions.git is a read-only mirror. New changes in the
github repo will be pushed to the mirror every 10 minutes.

Refer to [test writing guidelines](test-writing-guidelines.md) to modify
or add test.

Changes need to be able to pass sanity check, which by default checks files in the most
recent commit:

    ./sanity-check.sh

To develop locally, there are Dockerfiles in test/ that can be used to simulate
target environments. The easiest way to use is to run `test.sh
[debian|centos]`. test.sh will run validate.py, and then build the Docker
environment specified, run plans/linux-example.yaml, and then drop into a bash
shell inside the container so that things like /root/output can be inspected.
It is not (yet) a pass/fail test; merely a development helper and validation
environment.

For full documentation visit [test-definitions.readthedocs.io](https://test-definitions.readthedocs.io).
