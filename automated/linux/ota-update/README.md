This test consists of 3 parts:
 * download-update.yaml/static-delta.yaml
 * verify-upgrade.yaml
 * verify-reboot.yaml

download-update.yaml can be exchanged with static-delta.yaml. Static
delta test can exercise OTA update and full disk conditions. Testing
full disk with atomic ostree updates is almost impossible as ostree checks
the disk thresholds for each object and the objects are usually small.
For this reason there is no full disk condition in the download-update.yaml

To confirm full upgrade all 3 .yaml files need to be used in a test job.
The DUT needs to reboot twice during the job. Therefore interactive
shell is used as a part of the job. Example test job (testing part) below:

```
- test:
    namespace: before
    timeout:
      minutes: 10
    definitions:
    - repository: http://github.com/linaro/test-definitions.git
      from: git
      path: automated/linux/ota-upgrade/download-update.yaml
      name: prepare-kernel-upgrade
- test:
    namespace: before
    timeout:
      minutes: 1
    interactive:
    - name: kernel-poweroff
      prompts: []
      script:
      - command: poweroff
        name: poweroff
        wait_for_prompt: False
        successes:
        - message: "reboot: Power down"
- deploy:
    namespace: after
    connection-namespace: before
    timeout:
      minutes: 10
    to: downloads
    images:
      bootloader:
        url: <example file to download>
- boot:
    namespace: after
    connection-namespace: before
    prompts:
     - "Password:"
     - "root:"
    timeout:
      minutes: 10
    auto_login:
      login_prompt: 'login:'
      username: foo
      password_prompt: "Password:"
      password: "bar"
      login_commands:
      - sudo su
      - bar
    method: minimal
    transfer_overlay:
      download_command: wget
      unpack_command: tar -xzf
- test:
    namespace: after
    connection-namespace: before
    timeout:
      minutes: 5
    definitions:
    - repository: http://github.com/linaro/test-definitions.git
      from: git
      path: automated/linux/ota-upgrade/verify-upgrade.yaml
      name: verify-kernel-upgrade
      parameters:
        TARGET_VERSION: "123"
- deploy:
    namespace: after2
    connection-namespace: before
    timeout:
      minutes: 10
    to: downloads
    images:
      bootloader:
        url: <example file to download>
- boot:
    namespace: after2
    connection-namespace: before
    prompts:
     - "Password:"
     - "root:"
    timeout:
      minutes: 10
    auto_login:
      login_prompt: 'login:'
      username: foo
      password_prompt: "Password:"
      password: "bar"
      login_commands:
      - sudo su
      - bar
    method: minimal
    transfer_overlay:
      download_command: wget
      unpack_command: tar -xzf
- test:
    namespace: after2
    connection-namespace: before
    timeout:
      minutes: 5
    definitions:
    - repository: http://github.com/linaro/test-definitions.git
      from: git
      path: automated/linux/ota-update/verify-reboot.yaml
      name: verify-reboot
      parameters:
        TARGET_VERSION: "123"
```
