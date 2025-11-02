import pytest


@pytest.fixture(scope="session")
def command(target):
    shell = target.get_driver("ShellDriver")
    target.activate(shell)
    return shell


def test_command(command):
    stdout, stderr, returncode = command.run("cat /proc/version")
    assert returncode == 0
    assert stdout
    assert not stderr
    assert "Linux" in stdout[0]
