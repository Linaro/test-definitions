#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.

import os
import sys
from pathlib import Path
from typing import Any

import yaml
from jinja2 import BaseLoader, Environment, StrictUndefined
from jinja2.exceptions import UndefinedError


def render_external_drivers() -> dict[str, Any]:
    """
    Render power and console drivers using the settings from LAVA device dictionary.
    """

    if not os.getenv("LAVA_CONNECT_COMMAND") and os.getenv("LAVA_CONNECTION_COMMAND"):
        os.environ["LAVA_CONNECT_COMMAND"] = os.environ["LAVA_CONNECTION_COMMAND"]

    # ms -> s
    if txdelay := os.environ.get("LAVA_BOOT_CHARACTER_DELAYS") or os.environ.get(
        "LAVA_TEST_CHARACTER_DELAYS"
    ):
        try:
            os.environ["LAVA_CONNECTION_DELAY"] = str(int(txdelay) / 1000)
        except ValueError as e:
            print(f"Invalid LAVA_CONNECTION_DELAY '{txdelay}': {e}. Ignoring value.")

    tmpl_str = """
    ExternalPowerDriver:
        cmd_on: '{{ LAVA_POWER_ON_COMMAND }}'
        cmd_off: '{{ LAVA_POWER_OFF_COMMAND }}'
        cmd_cycle: 'sh -c "{{ LAVA_HARD_RESET_COMMAND }}"'
        delay: 3.0
    ExternalConsoleDriver:
        cmd: '{{ LAVA_CONNECT_COMMAND or LAVA_CONNECTION_COMMAND }}'
        txdelay: {{ LAVA_CONNECTION_DELAY | default(0.0) }}
    """

    env = Environment(
        loader=BaseLoader(),
        undefined=StrictUndefined,
    )
    tmpl = env.from_string(tmpl_str)

    try:
        rendered = tmpl.render(**os.environ)
    except UndefinedError as e:
        print(f"ERROR: {e}")
        raise SystemExit(1)

    return yaml.safe_load(rendered)


def update_config(lg_env: dict[str, Any]) -> str:
    """
    Remove the existing power and console drivers and add the ones rendered from lava
    dictionary.

    This replacement is necessary to avoid driver conflicts because multiple drivers
    with the same protocol and priority are not allowed and driver priority is a class
    variable, not a yaml option yet.
    """

    external_drivers = render_external_drivers()

    drivers_to_remove = [
        "ManualPowerDriver",
        "ExternalPowerDriver",
        "NetworkPowerDriver",
        "PDUDaemonDriver",
        "ExternalConsoleDriver",
        "SerialDriver",
    ]

    for _, conf in lg_env.get("targets", {}).items():
        if drivers := conf.get("drivers"):
            # Labgrid supports both list and dict for resources/drivers.
            if isinstance(drivers, list):
                # Convert list to dict.
                section_dict = {}
                for item in drivers:
                    section_dict.update(item)
                drivers = section_dict

            if isinstance(drivers, dict):
                for key in list(drivers.keys()):
                    if key in drivers_to_remove:
                        drivers.pop(key)
                conf["drivers"] = {**external_drivers, **drivers}
            else:
                print(f"ERROR: 'drivers' should be a list or dict")
                raise SystemExit(1)

    return yaml.dump(lg_env, default_flow_style=False, sort_keys=False, indent=2)


def main() -> None:
    # load and update labgrid env.yaml.
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <labgrid-env-file>")
        raise SystemExit(1)

    lg_env_file = Path(sys.argv[1])
    if not lg_env_file.exists():
        print(f"ERROR: {lg_env_file} does not exist")
        raise SystemExit(1)

    lg_env_str = lg_env_file.read_text()
    print(f"--- Original labgrid env config ---\n{lg_env_str}")
    lg_env = yaml.safe_load(lg_env_str)

    updated_lg_env_str = update_config(lg_env)
    lg_env_file.write_text(updated_lg_env_str)
    print(f"--- Updated labgrid env config ---\n{lg_env_file.read_text()}")


if __name__ == "__main__":
    main()
