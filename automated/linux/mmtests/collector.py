from typing import Dict, List, Optional, Union, Any
import argparse
import json
import re
import os
import sys
from pathlib import Path
import subprocess
import shutil
import hashlib
import logging

logging.basicConfig(
    level=logging.DEBUG, format="%(asctime)s - R.CLCTR - %(levelname)s - %(message)s"
)
log = logging.getLogger(__name__)

UNKNOWN = "UNKNOWN"
RESULTS_OK = "/tmp/check_results_ok"
# Note 1: it would be better to add lshw, dmidecode, and other tools to the image
# to collect more detailed information about the system.
# Note 2: script will work only on Debian-like systems


def capture_env(cmd) -> Dict[str, str]:
    """Executes a command using subprocess and captures environment variables.
    :param cmd: Command string to execute.
    :return: A dictionary of the environment variables with their values.
    """
    output = run_cmd(cmd, timeout=30)
    if not output:
        return {}

    capture = {}
    for line in output.split("\n"):
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            try:
                parts = line.split("=", 1)
                if len(parts) == 2:
                    var_name, var_value = parts
                    capture[var_name] = var_value
            except (ValueError, IndexError):
                continue
    return capture


def collect_vars(c_path: Path, iterations: int) -> Dict[str, Any]:
    """Sources the config file and extracts only the variables that were exported.
    :param c_path: Path to the configuration file
    :param iterations: Number of iterations for MMTests
    :return: A dict of the sourced env vars
    """
    pre_env = capture_env("env")
    post_env = capture_env(f"source {c_path} && env")
    # Find diff
    exported_variables = {
        key: value
        for key, value in post_env.items()
        if key not in pre_env or value != pre_env.get(key)
    }
    exported_variables["MMTESTS_ITERATIONS"] = iterations
    exported_variables["MMTESTS_CONFIG"] = c_path.stem

    return exported_variables


def run_cmd(cmd: str, timeout: int = 30) -> str:
    """Run a shell command and return its output as a string.
    :param cmd: Command to execute
    :param timeout: Command timeout in seconds
    :return: Command output or empty string on failure
    """
    try:
        # Prevent exception on non-zero exit
        # Note: we assume that bash is available on the system
        result = subprocess.run(
            cmd,
            shell=True,
            executable="/bin/bash",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
            check=False,
        )

        if result.returncode != 0:
            log.error(
                "Command failed with exit code %d: %s. Output: %s",
                result.returncode,
                cmd,
                result.stdout,
            )
            return ""

        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        log.error("Command timed out after %d seconds: %s", timeout, cmd)
        return ""
    except Exception as e:
        log.error("Command execution failed: %s. Error: %s", cmd, e)
        return ""


def parse_cpu_info() -> Dict[str, Any]:
    """Parse CPU information from lscpu command."""
    if not if_cmd_exists("lscpu"):
        log.warning("CPU info not available")
        return {
            "Arch": UNKNOWN,
            "Cores": 0,
            "Frequency": f"{UNKNOWN} MHz",
            "Caches": {},
        }

    cpu_info = run_cmd("lscpu")
    if not cpu_info:
        log.error("Failed to get CPU information")
        return {
            "Arch": UNKNOWN,
            "Cores": 0,
            "Frequency": f"{UNKNOWN} MHz",
            "Caches": {},
        }

    caches = {}
    for line in cpu_info.splitlines():
        line = line.strip()
        if "cache" in line.lower() and ":" in line:
            try:
                parts = line.split(":", 1)
                if len(parts) == 2:
                    caches[parts[0].strip()] = parts[1].strip()
            except Exception as e:
                log.warning("Failed to parse cache line '%s': %s", line, e)

    arch = UNKNOWN
    arch_match = re.search(r"Architecture:\s+(\S+)", cpu_info)
    if arch_match:
        arch = arch_match.group(1)
    else:
        log.warning("Could not parse CPU architecture")

    cores = 0
    cores_match = re.search(r"^CPU\(s\):\s+(\d+)", cpu_info, re.MULTILINE)
    if cores_match:
        try:
            cores = int(cores_match.group(1))
        except ValueError as e:
            log.error("Failed to parse CPU cores: %s", e)
    else:
        log.warning("Could not parse CPU core count")

    freq = UNKNOWN
    freq_match = re.search(r"CPU MHz:\s+(\S+)", cpu_info)
    if freq_match:
        try:
            freq_val = float(freq_match.group(1))
        except ValueError as e:
            log.warning("Failed to parse CPU frequency: %s", e)

    return {
        "Arch": arch,
        "Cores": cores,
        "Frequency": f"{freq} MHz",
        "Caches": caches,
    }


def parse_memory_info() -> Dict[str, str]:
    """Parse memory information from /proc/meminfo."""
    proc_mem = "/proc/meminfo"
    log.info("Trying to read: %s", proc_mem)
    try:
        with open(proc_mem, "r", encoding="utf-8") as f:
            content = f.read()
            for line in content.splitlines():
                if line.startswith("MemTotal:"):
                    mem_info = line
                    break
            else:
                mem_info = ""
    except (OSError, PermissionError) as exc:
        log.error("Failed to read %s: %s", proc_mem, exc)
        return {
            "Total": f"{UNKNOWN} MB",
            "Speed": UNKNOWN,
        }

    if not mem_info:
        log.error("Failed to get memory information")
        return {
            "Total": f"{UNKNOWN} MB",
            "Speed": UNKNOWN,
        }

    match = re.search(r"MemTotal:\s+(\d+)\s+kB", mem_info)
    if not match:
        log.error("Could not parse memory total from: %s", mem_info)
        return {
            "Total": f"{UNKNOWN} MB",
            "Speed": UNKNOWN,
        }

    total_kb = int(match.group(1))
    # Convert kB to MB
    total_mb = total_kb // 1024
    return {
        "Total": f"{total_mb} MB",
        "Speed": UNKNOWN,
    }


def get_instance_type() -> str:
    """Get the instance type from the environment variable"""
    return os.getenv("INSTANCE_TYPE", UNKNOWN)


def parse_storage_info() -> Dict[str, List[Dict[str, Any]]]:
    """Parse storage information from lsblk command."""
    if not if_cmd_exists("lsblk"):
        log.warning("Storage information not available")
        return {"Disks": []}

    block_output = run_cmd("lsblk -b -o NAME,SIZE,TYPE,MOUNTPOINT")
    if not block_output:
        log.error("Failed to get storage information from lsblk")
        return {"Disks": []}

    lines = block_output.splitlines()
    # Need at least header + one data line
    if len(lines) < 2:
        log.warning("No storage devices found")
        return {"Disks": []}

    # Skip header line
    block_info = lines[1:]
    disks = []
    current_disk = {}

    for line in block_info:
        line = line.strip()
        if not line:
            continue

        parts = line.split()
        if len(parts) < 3:
            log.warning("Malformed lsblk line: %s", line)
            continue

        try:
            name = parts[0]
            # Remove Unicode characters
            name = re.sub(r"[\u2500-\u257F]", "", name)
            size_bytes = int(parts[1])
            size_gb = size_bytes // (1024**3)
            size = f"{size_gb}G"

            block_type = parts[2]
            mountpoint = parts[3] if len(parts) > 3 else "Not mounted"

            if block_type == "disk":
                if current_disk:
                    disks.append(current_disk)
                current_disk = {"Name": name, "Size": size, "Partitions": []}
            elif block_type == "part" and current_disk:
                partition = {"Name": name, "Size": size, "Mountpoint": mountpoint}
                current_disk["Partitions"].append(partition)

        except (ValueError, IndexError) as e:
            log.warning("Failed to parse storage line '%s': %s", line, e)
            continue

    if current_disk:
        disks.append(current_disk)

    log.info("Found %d storage devices", len(disks))
    return {"Disks": disks}


def parse_os_info() -> Dict[str, Any]:
    """Parse OS information from /etc/os-release."""
    os_release_file = "/etc/os-release"
    packages = get_installed_packages()

    if not if_file_exists(os_release_file, "file"):
        log.warning("OS release file not found: %s", os_release_file)
        return {
            "Name": UNKNOWN,
            "Packages list": packages,
        }

    with open(os_release_file, "r", encoding="utf-8") as f:
        for line in f:
            if line.startswith("PRETTY_NAME"):
                parts = line.split("=", 1)
                if len(parts) < 2:
                    continue
                os_info = parts[1].strip().strip('"')
                return {
                    "Name": os_info,
                    "Packages list": packages,
                }


def get_installed_packages() -> Dict[str, str]:
    """Get a list of installed packages"""
    if not if_cmd_exists("dpkg"):
        log.info("Not a Debian-based system")
        return {}

    output = run_cmd("dpkg -l", timeout=60)
    if not output:
        log.error("Failed to get package list from dpkg")
        return {}

    packages = {}

    patt = re.compile(r"^ii\s+([a-zA-Z0-9][a-zA-Z0-9+.\-:]+)\s+(\S+)")
    for line in output.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        match = patt.match(line)
        if match:
            package_name, version = match.groups()
            packages[package_name] = version

    log.info("Found %d installed packages", len(packages))
    return packages


def parse_kernel_info() -> Dict[str, str]:
    """Parse kernel version"""
    if not if_cmd_exists("uname"):
        log.warning("Kernel information not available")
        return {
            "Version": UNKNOWN,
            "SHA256": UNKNOWN,
        }

    kernel_version = run_cmd("uname -r")
    if not kernel_version:
        log.error("Failed to get kernel version from uname")
        kernel_version = UNKNOWN

    return {
        "Version": kernel_version,
        "SHA256": collect_sha256_kernel(kernel_version),
    }


def parse_filesystem_info() -> Dict[str, List[Dict[str, str]]]:
    """Parse filesystem information from df command."""
    if not if_cmd_exists("df"):
        log.info("Filesystem information no available")
        return {"Filesystems": []}

    df_output = run_cmd("df -Th")
    if not df_output:
        log.error("Failed to get filesystem information from df")
        return {"Filesystems": []}

    lines = df_output.splitlines()
    # Need at least header + one data line
    if len(lines) < 2:
        log.warning("No filesystem information found")
        return {"Filesystems": []}

    # Skip header
    df_info = lines[1:]
    fses = []
    for line in df_info:
        line = line.strip()
        if not line:
            continue

        try:
            parts = line.split(None, 6)
            if len(parts) < 7:
                log.warning("Malformed df line (insufficient fields): %s", line)
                continue

            name, fs_type, size, used, avail, use_perc, mounted_on = parts
            # Filter out loop and tmpfs
            if "loop" not in name and "tmpfs" not in fs_type:
                fs = {
                    "Name": name,
                    "Type": fs_type,
                    "Size": size,
                    "Used": used,
                    "Avail": avail,
                    "Use%": use_perc.rstrip("%"),
                    "Mounted on": mounted_on,
                }
                fses.append(fs)
        except ValueError as e:
            log.warning("Failed to parse filesystem line '%s': %s", line, e)
            continue

    log.info("Found %d filesystems", len(fses))
    return {"Filesystems": fses}


def get_file_sha256(file_path: Union[str, Path]) -> str:
    """Calculate the SHA256 hash of a file"""
    sha256_hash = hashlib.sha256()
    block_size = 4096
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(block_size), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()


def get_current_kernel_loc(ver: str) -> Optional[str]:
    """Get the location of the current kernel binary"""
    loc = f"/boot/vmlinuz-{ver}"
    if if_file_exists(loc, "file"):
        return loc
    log.error("Kernel file does not exist: %s", loc)
    return None


def collect_sha256_kernel(ver: str) -> str:
    """Collect the SHA256 hash of the current kernel"""
    loc = get_current_kernel_loc(ver)
    if loc:
        sha256 = get_file_sha256(loc)
        return sha256
    log.error("cannot get SHA256 for kernel: %s", ver)
    return UNKNOWN


def read_sha256_file(file_path: Union[str, Path]) -> str:
    """Read the SHA256 hash from a file"""
    if not if_file_exists(file_path, "file"):
        log.error("SHA256 file does not exist: %s", file_path)
        return UNKNOWN

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
            lines = content.splitlines()

            if not lines:
                log.error("SHA256 file is empty: %s", file_path)
                return UNKNOWN

            line = lines[0].strip()
            if not line:
                log.error("First line of SHA256 file is empty: %s", file_path)
                return UNKNOWN

            parts = line.split()
            if not parts:
                log.error("No content found in SHA256 file: %s", file_path)
                return UNKNOWN

            sha256 = parts[0]
            return sha256

    except (OSError, PermissionError) as e:
        log.error("Unable to read SHA256 file %s: %s", file_path, e)
        return UNKNOWN
    except UnicodeDecodeError as e:
        log.error("Unable to decode SHA256 file %s: %s", file_path, e)
        return UNKNOWN
    except Exception as e:
        log.error("Unexpected error reading SHA256 file %s: %s", file_path, e)
        return UNKNOWN


def collect_sha256_benchmark(cfg_name: str) -> str:
    """Collect the SHA256 hash of the benchmark"""
    loc = f"/mmtests/{cfg_name}.SHA256"
    if if_file_exists(loc, "file"):
        return read_sha256_file(loc)
    else:
        log.warning("Unable to find file: %s", loc)
        return UNKNOWN


def if_file_exists(
    file_path: Union[str, Path], file_type: str = "file"
) -> Optional[Path]:
    """Check if a file or directory exists.
    :param file_path: Path to check (str or Path object)
    :param file_type: Type to check - 'file', 'dir', or 'any'
    :return: Path object if exists and matches type, None otherwise
    """
    if not file_path:
        return None

    try:
        path = Path(file_path)
        if not path.exists():
            return None

        if file_type == "file" and path.is_file():
            return path
        elif file_type == "dir" and path.is_dir():
            return path
        elif file_type == "any":
            return path
        else:
            return None
    except (OSError, ValueError):
        return None


def if_cmd_exists(cmd: str) -> bool:
    """Check if a command is available in the system PATH.
    :param cmd: Command name to check
    :return: True if command exists, False otherwise
    """
    if not shutil.which(cmd):
        log.warning("%s command is not available", cmd)
        return False
    return True


def parse_boottime() -> Dict[str, Dict[str, Any]]:
    """Parse the system boot time."""
    time_patt = re.compile(r"(\d+(?:\.\d+)?)(ms|us|s)")

    def parse_time(t):
        match = time_patt.match(t.strip())
        if not match:
            return 0
        try:
            value, unit = match.groups()
            value = float(value)
            if unit == "ms":
                return int(value)
            if unit == "us":
                return int(value / 1000)
            return int(value * 1000)
        except (ValueError, OverflowError):
            return 0

    blame_info = {}
    time_info = {}

    if not if_cmd_exists("systemd-analyze"):
        log.warning("System boot time information is not available")
        return {"blame": blame_info, "time": time_info}

    try:
        if if_cmd_exists("systemd-analyze"):
            blame_output = run_cmd("systemd-analyze blame")
        else:
            blame_output = ""

        if blame_output:
            for line in blame_output.splitlines():
                line = line.strip()
                if not line:
                    continue

                try:
                    parts = line.split(maxsplit=1)
                    if len(parts) == 2:
                        time_str, name = parts
                        blame_info[name] = parse_time(time_str)
                except ValueError as e:
                    log.warning("Failed to parse blame line '%s': %s", line, e)
                    continue
    except Exception as e:
        log.error("Parsing blame output: %s", e)

    try:
        if if_cmd_exists("systemd-analyze"):
            time_output = run_cmd("systemd-analyze time")
        else:
            time_output = ""

        if time_output:
            lines = time_output.splitlines()
            if lines:
                line = lines[0].strip()
                startup_match = re.search(
                    r"Startup finished in ([\d.]+)s \(kernel\) \+ ([\d.]+)s \(userspace\) = ([\d.]+)s",
                    line,
                )
                if startup_match:
                    try:
                        kernel_time = float(startup_match.group(1))
                        userspace_time = float(startup_match.group(2))
                        total_time = float(startup_match.group(3))

                        time_info = {
                            "kernel": kernel_time,
                            "userspace": userspace_time,
                            "total": total_time,
                        }
                    except ValueError as e:
                        log.error("Failed to parse startup times: %s", e)
                else:
                    log.warning("Could not parse startup time format: %s", line)

                # Parse graphical target time if present
                if len(lines) > 1:
                    graphical_match = re.search(
                        r"graphical\.target reached after ([\d.]+)s", lines[1]
                    )
                    if graphical_match:
                        try:
                            time_info["graphical_target"] = float(
                                graphical_match.group(1)
                            )
                        except ValueError as e:
                            log.warning("Failed to parse graphical target time: %s", e)
    except Exception as e:
        log.error("Parsing time output: %s", e)

    return {"blame": blame_info, "time": time_info}


def collect_system_info(cfg_name: str) -> Dict[str, Any]:
    """Build a dictionary with system information."""
    return {
        "CPU": parse_cpu_info(),
        "Memory": parse_memory_info(),
        "Storage": parse_storage_info(),
        "OS": parse_os_info(),
        "Kernel": parse_kernel_info(),
        "Filesystem": parse_filesystem_info(),
        "Instance type": get_instance_type(),
        "Benchmark SHA256": collect_sha256_benchmark(cfg_name),
        "Boot time": parse_boottime(),
    }


def mmtest_extract_json(
    benchmark: str, r_root: Union[str, Path], c_name: str, extractor: Union[str, Path]
) -> Optional[Dict[str, Any]]:
    """Extracts benchmark results in JSON format.
    :param benchmark: Benchmark name
    :param r_root: The root directory where the results are stored
    :param c_name: The name of the MMTests config file
    :param extractor: Path to the extract-mmtests.pl script
    """
    if not all([benchmark, r_root, c_name, extractor]):
        log.error("Missing required parameters for mmtest_extract_json")
        return None

    if not re.match(r"^[a-zA-Z0-9][a-zA-Z0-9\-_.]*$", str(benchmark)):
        log.error("Invalid benchmark name: %s", benchmark)
        return None

    if not re.match(r"^[a-zA-Z0-9][a-zA-Z0-9\-_.]*$", str(c_name)):
        log.error("Invalid config name: %s", c_name)
        return None

    if not if_file_exists(extractor, "file"):
        log.error("Extractor script not found: %s", extractor)
        return None

    if not if_file_exists(r_root, "dir"):
        log.error("Results root directory not found: %s", r_root)
        return None

    command = f"{extractor} -d {r_root} -b {benchmark} -n {c_name} --print-json"
    json_output = run_cmd(command, timeout=300)
    if not json_output:
        log.error("No output from extraction command for benchmark %s", benchmark)
        return None

    try:
        results_data = json.loads(json_output)

        if results_data:
            return results_data
        else:
            log.warning("Empty results data for benchmark %s", benchmark)
            return None

    except json.JSONDecodeError as e:
        log.error("Failed to parse JSON results for benchmark %s: %s", benchmark, e)
        return None
    except Exception as e:
        log.error("Unexpected error parsing results for benchmark %s: %s", benchmark, e)
        return None


def check_results(results_data: Dict[str, Any]) -> bool:
    """Checks the extracted JSON results for specific conditions."""
    errors = False

    if "_OperationsSeen" not in results_data:
        log.error("_OperationsSeen is not present in the results data")
        errors = True

    if len(results_data.get("_OperationsSeen", {})) == 0:
        log.error("_OperationsSeen is empty")
        errors = True

    if "_ResultData" not in results_data:
        log.error("_ResultData is not present in the results data")
        errors = True

    if len(results_data.get("_ResultData", {}).keys()) == 0:
        log.error("_ResultData is empty")
        errors = True

    return errors


def get_results_root(test_dir: Union[str, Path]) -> Path:
    """Get the results directory from the test directory"""
    result = Path(test_dir) / "work/log"
    if not if_file_exists(result, "dir"):
        log.error("results dir %s does not exist", result)
        raise FileNotFoundError
    return result


def get_names(target_dir: Union[str, Path]) -> List[str]:
    """Get the names of the benchmarks from the results directory
    :param target_dir: The directory where the results are stored
    :return: A list of benchmark names
    """
    target_path = Path(target_dir) / "iter-0"
    if not if_file_exists(target_path, "dir"):
        log.error("Target directory does not exist: %s", target_path)
        return []

    result = []
    try:
        for root, _, _ in os.walk(str(target_path)):
            if root.endswith("logs"):
                match = re.search(r"/iter-0/([^/]+)/logs$", root)
                if match:
                    benchmark_name = match.group(1)
                    result.append(benchmark_name)
    except OSError as e:
        log.error("Failed to walk directory %s: %s", target_path, e)
        return []

    log.info("Found %d benchmarks", len(result))
    return result


def compose_filename(benchmark: str, c_name: str) -> str:
    """Compose output name for JSON file"""
    return f"BENCHMARK{benchmark}_CONFIG{c_name}.json"


def collect_times(r_dir: Path):
    """Collect start and finish times for each test"""
    result = {}
    if not if_file_exists(r_dir, "dir"):
        log.error("Results directory does not exist: %s", r_dir)
        return result

    patterns = {
        "start": re.compile(r"start :: (\d+)"),
        "finish": re.compile(r"finish :: (\d+)"),
        "test_begin": re.compile(r"test begin :: \w+ (\d+)"),
        "test_end": re.compile(r"test end :: \w+ (\d+)"),
    }

    try:
        for item in r_dir.iterdir():
            iter_data = {}
            times_file = item / "tests-timestamp"

            if if_file_exists(times_file, "file"):
                try:
                    with times_file.open("r", encoding="utf-8") as f:
                        file_contents = f.read()
                        for key, pattern in patterns.items():
                            match = pattern.search(file_contents)
                            if match:
                                try:
                                    iter_data[key] = int(match.group(1))
                                except ValueError as e:
                                    log.warning(
                                        "Failed to parse timestamp for %s: %s", key, e
                                    )
                except (OSError, PermissionError) as e:
                    log.error("Failed to read timestamp file %s: %s", times_file, e)
                    continue
                except UnicodeDecodeError as e:
                    log.error("Failed to decode timestamp file %s: %s", times_file, e)
                    continue

            if iter_data:
                result[item.name] = iter_data

    except OSError as e:
        log.error("Failed to iterate results directory %s: %s", r_dir, e)
        return {}

    log.info("Collected timing data for %d iterations", len(result))
    return result


def parse_args() -> Any:
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Collect SUT information and environment vars"
    )
    parser.add_argument(
        "-o",
        metavar="OUTPUT_DIR",
        required=True,
        help="Output dir path",
    )
    parser.add_argument(
        "-c",
        metavar="MMTESTS_CONFIG_FILE",
        required=True,
        help="Path to MMTests config file, e.g. configs/config-name",
    )
    parser.add_argument(
        "-d", metavar="TEST_DIR", required=True, help="Specify test directory"
    )
    parser.add_argument(
        "-i",
        metavar="MMTEST_ITERATIONS",
        type=int,
        required=True,
        help="Number of iterations for MMTests",
    )
    parser.add_argument("-f", action="store_true", help="Collect full archive")

    try:
        result = parser.parse_args()
    except SystemExit:
        log.error("Failed to parse command line arguments")
        raise

    try:
        test_dir = Path(result.d).resolve()
    except (OSError, ValueError) as e:
        log.error("Invalid test directory path '%s': %s", result.d, e)
        sys.exit(1)

    if not if_file_exists(test_dir, "dir"):
        log.error("TEST_DIR %s does not exist or is not a directory", test_dir)
        sys.exit(1)

    if not result.c or len(result.c) > 255:
        log.error("Invalid config file path: %s", result.c)
        sys.exit(1)

    try:
        c_path = (test_dir / result.c).resolve()
        c_path.relative_to(test_dir)
    except (OSError, ValueError) as e:
        log.error("Invalid config file path '%s': %s", result.c, e)
        sys.exit(1)

    if not if_file_exists(c_path, "file"):
        log.error("MMTESTS_CONFIG_FILE %s does not exist or is not a file", c_path)
        sys.exit(1)

    try:
        Path(result.o).resolve()
    except (OSError, ValueError) as e:
        log.error("Invalid output directory path '%s': %s", result.o, e)
        sys.exit(1)

    return result


if __name__ == "__main__":
    args = parse_args()

    mmtest_extr = f"{args.d}/bin/extract-mmtests.pl"
    config_path = Path(args.d) / Path(args.c)
    config_name = config_path.stem
    output_dir = Path(args.o)

    # This is global info
    variables = collect_vars(config_path, args.i)
    info = collect_system_info(config_name)

    results_root = get_results_root(args.d)
    results_dir = results_root / config_name

    if not if_file_exists(results_dir, "dir"):
        log.error("results dir '%s' does not exist", results_dir)
        sys.exit(1)

    # Clean up the results check file after previous run
    try:
        if if_file_exists(RESULTS_OK, "file"):
            os.remove(RESULTS_OK)
            log.debug("Removed previous results check file")
    except (OSError, PermissionError) as e:
        log.warning("Failed to remove results check file: %s", e)

    if args.f:
        try:
            shutil.copytree(results_dir, output_dir / results_dir.stem)
            log.info("full results dir collected in %s", output_dir)
        except FileNotFoundError:
            log.error("the results directory does not exist")

    times = collect_times(results_dir)

    benchmarks = get_names(results_dir)
    log.info("benchmarks detected: %s", ", ".join(benchmarks))

    for bench in benchmarks:
        output_file = compose_filename(bench, config_name)
        output_path = output_dir / output_file
        results = mmtest_extract_json(bench, results_root, config_name, mmtest_extr)

        if check_results(results):
            log.error("results check failed for %s", bench)
            sys.exit(1)
        else:
            log.info("results check passed for %s", bench)
            with open(RESULTS_OK, "w", encoding="utf-8") as file:
                pass

        data = {
            "variables": variables,
            "sys_info": info,
            "results": results,
            "times": times,
        }

        with open(output_path, "w", encoding="utf-8") as json_file:
            json.dump(data, json_file, indent=2)
            log.info("results collected to %s", output_path)
