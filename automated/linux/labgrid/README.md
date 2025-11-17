# Running Labgrid tests in LAVA

## Prepare LAVA device dictionary

In the LAVA device dictionary, the following power control and serial connection
commands and the optional character delay should be defined. The variables are exposed
to the LAVA docker test shell environment using the mappings shown below.

```yaml
# power control
"power_on_command": "LAVA_POWER_ON_COMMAND",
"power_off_command": "LAVA_POWER_OFF_COMMAND",
"hard_reset_command": "LAVA_HARD_RESET_COMMAND",
# serial connection
"connection_command": "LAVA_CONNECT_COMMAND",
"boot_character_delay": "LAVA_CONNECTION_DELAY",
```

Since LAVA uses a docker container to run Labgrid tests, the network addresses and the
devices referenced by the commands should be accessible from within the container. Extra
docker arguments can be added to configure network model, and to map required devices.

A device dictionary example:

```jinja2
{% extends 'bcm2837-rpi-3-b-32.jinja2' %}

{% set connection_command = 'telnet 192.168.18.6 2001' %}

{% set hard_reset_command = ['usbrelay 1_1=0', 'sleep 1', 'usbrelay 1_1=1'] %}
{% set power_off_command = 'usbrelay 1_1=0' %}
{% set power_on_command =  ['usbrelay 1_1=1'] %}

{% set boot_character_delay = 100 %}
{% set test_character_delay = 100 %}

{% set docker_shell_extra_arguments = [
    '--device=/dev/hidraw0'
] %}
```

> [!TIP]
> You may need to add or adjust the character delay depending on the device. For
example, my RPi3 serial console works fine without any delay in LAVA, but requires a
small delay when used with Labgrid.

## Review Labgrid env configure

By default, the Labgrid environment configure is updated using variables provided in
LAVA dictionary. `ExternalPowerDriver` and `ExternalConsoleDriver` drivers are generated
using the variables and added to the top of the drivers list. The priority attribute of
Labgrid power and console drivers is a class variable and cannot be configured in yaml
yet.

Configures in the below common power and serial modules are dropped. If you are using
other power and console modules, the options are:

* Remove them manually.
* Update the `update_env.py` script to remove them.
* Set the test definition parameter `UPDATE_ENV` to `false` to use them.

```bash
ExternalPowerDriver
ManualPowerDriver
NetworkPowerDriver
PDUDaemonDriver
ExternalConsoleDriver
SerialDriver
```

## LAVA job definition examples

### Running labgrid shell-based test

Labgrid shell-based tests expect the DUT(Device Under Test) is booted to a shell
already. The lava job example below boots the default OS pre-deployed to the DUT to bash
shell, and then starts a docker container to execute the labgrid tests.

```yaml
job_name: rpi3-docker-shell-labgrid-shell
device_type: bcm2837-rpi-3-b-32
priority: high
visibility: public
timeouts:
  action:
    minutes: 15
  job:
    minutes: 30

actions:
  - boot:
      method: minimal
      auto_login:
        login_prompt: " login: "
        username: "root"
        password_prompt: "Password: "
        password: "root123"
      prompts:
        - 'root@\w+:[^ ]+ '

  - test:
      disconnect_connection: true
      docker:
        image: python:3.13
        local: true
      definitions:
      - repository: https://github.com/Linaro/test-definitions.git
        from: git
        path: automated/linux/labgrid/labgrid.yaml
        parameters:
          UPDATE_ENV: true
          LG_ENV: "./tests/example/env.yaml"
          LG_TEST: "./tests/example/test_shell.py"
          DEB_PKGS: "usbrelay"
        name: labgrid-shell-example
```

When needed, you can add more lava deploy and boot actions before the test action. LAVA
is capable for various image deployments and boots.

If your serial console is configured to allow multiple connections
(e.g., `ser2net` with `max-connections: 2`), you don't need to set
`disconnect_connection: true` in the test action. And LAVA will provide feedback from
serial console at the end of the job. It is a good plus and could be even more helpful
for debugging.

### Running labgrid strategy-based tests

Labgrid strategies allow the labgrid library to bring the DUT to a defined state, such
as the U-Boot bootloader or a Linux shell, and then run tests.

The following job example starts a lava docker test shell directly and let labgrid
handle the rest. This behaves the same as running labgrid from your laptop, but inside
an isolated container.

```yaml
job_name: rpi3-labgrid-shell-strategy
device_type: bcm2837-rpi-3-b-32
priority: high
visibility: public
timeouts:
  job:
    minutes: 30

actions:
 - test:
     docker:
       image: python:3.13
       local: true
     definitions:
     - repository: https://github.com/Linaro/test-definitions.git
       from: git
       path: automated/linux/labgrid/labgrid.yaml
       parameters:
         UPDATE_ENV: true
         LG_ENV: "./tests/example/env.yaml"
         LG_TEST: "./tests/example/test_shell_strategy.py"
         DEB_PKGS: "usbrelay"
       name: labgrid-shell-strategy-example
```
