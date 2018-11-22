# Usage of dockerized tests

## Local execution
### Issue commands manually
  Without customized test parameters:
  ```
  # docker run --privileged --init linaro/testdef-arm64-debian-stretch:2018.08 test-runner -d automated/linux/smoke/smoke.yaml
  ```

  With customized test parameters:
  ```
  # docker run --privileged --init linaro/testdef-arm64-debian-stretch:2018.08 test-runner -d automated/linux/ltp/ltp.yaml -r TST_CMDFILES=syscalls SKIPFILE=skipfile-lkft.yaml BOARD=hi6220-hikey BRANCH=4.16 ENVIRONMENT=production
  ```

### Using local-run.sh
   ```
   # ./local-run.sh -d linaro/testdef-arm64-debian-stretch:2018.08 -t automated/linux/dd-wr-speed/dd-wr-speed.yaml -r ITERATION=3
   ```
## Test run in LAVA
   Test action example:
   ```
   - test:
     namespace: hikey
     timeout:
       minutes: 120
     definitions:
     - repository: https://git.linaro.org/qa/test-definitions.git
       from: git
       path: automated/linux/dockerized-tests/local-run.yaml
       name: smoke
       parameters:
         DOCKER_IMG: "linaro/testdef-arm64-debian-stretch:2018.08"
         TEST: automated/linux/smoke/smoke.yaml
       timeout:
         # The first test needs time to pull and extract docker image.
         minutes: 30
     - repository: https://git.linaro.org/qa/test-definitions.git
       from: git
       path: automated/linux/dockerized-tests/local-run.yaml
       name: ltp-syscalls
       parameters:
         DOCKER_IMG: "linaro/testdef-arm64-debian-stretch:2018.08"
         TEST: automated/linux/ltp/ltp.yaml
         TESTDEF_PARAMS: "TST_CMDFILES='syscalls' SKIPFILE='skipfile-lkft.yaml' BOARD='hi6220-hikey' BRANCH='4.16' ENVIRONMENT='production'"
       timeout:
         minutes: 90
    ```
## Drive test run via SSH
  The same as local-run, but use over-ssh.yaml and over-ssh.sh instead and provide required additional parameters.
  ```
  TARGET_IP: ""
  SSH_USER: ""
  SSH_PASSWD: ""
  ```

## Dockerfiles

  [stretch-arm64-testdef](https://git.linaro.org/ci/dockerfiles.git/tree/stretch-arm64-testdef)

  [stretch-armhf-testdef](https://git.linaro.org/ci/dockerfiles.git/tree/stretch-armhf-testdef)

## Jenkins build job for new tag on qa/test-definitions
  [testdef-docker-image-arm64](https://ci.linaro.org/job/testdef-docker-image/)
  [testdef-docker-image-armhf](https://ci.linaro.org/job/testdef-docker-image-armhf/)
