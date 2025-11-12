import pytest


@pytest.fixture(scope="function")
def in_bootloader(strategy, capsys):
    with capsys.disabled():
        strategy.transition("uboot")


# Power reset -> uboot shell
def test_uboot(target, in_bootloader):
    command = target.get_driver("UBootDriver")

    stdout, stderr, returncode = command.run("version")
    assert returncode == 0
    assert stdout
    assert not stderr
    assert "U-Boot" in "\n".join(stdout)
