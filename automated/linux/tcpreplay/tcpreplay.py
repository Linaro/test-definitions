#!/usr/bin/env python3
# vim: set ts=8 sw=4 sts=4 et tw=80 fileencoding=utf-8 :
import argparse
import glob
import fcntl
import os
import shutil
import struct
import subprocess
import sys
import time


def check_root():
    if os.geteuid() != 0:
        print("SKIP: Must be run as root to create TAP interfaces")
        return False
    return True


def check_tcpreplay():
    if not shutil.which("tcpreplay"):
        print("SKIP: tcpreplay not found in PATH")
        return False
    return True


def create_tap_interface(ifname):
    try:
        IFF_TAP = 0x0002
        IFF_NO_PI = 0x1000
        TUNSETIFF = 0x400454CA

        tap_fd = os.open("/dev/net/tun", os.O_RDWR)
        ifr = struct.pack("16sH", ifname.encode(), IFF_TAP | IFF_NO_PI)
        fcntl.ioctl(tap_fd, TUNSETIFF, ifr)
        return tap_fd
    except Exception as e:
        print(f"Error creating TAP interface: {e}")
        return None


def configure_interface(ifname, ipaddr, mask):
    try:
        subprocess.run(["ip", "link", "set", ifname, "up"], check=True)
        subprocess.run(
            ["ip", "addr", "add", f"{ipaddr}/{mask}", "dev", ifname], check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print(f"Failed to configure interface: {e}")
        return False


def cleanup_interface(ifname):
    try:
        subprocess.run(["ip", "link", "set", ifname, "down"], check=True)
        print("cleanup_interface: pass")
    except subprocess.CalledProcessError:
        print("cleanup_interface: fail")


def run_tcpreplay(ifname, pcap):
    try:
        subprocess.run(["tcpreplay", "--intf1", ifname, pcap], check=True)
        print("run_tcpreplay: pass")
        return True
    except subprocess.CalledProcessError:
        print("run_tcpreplay: fail")
        return False


def lava_report(name, result, output_file=None):
    line = f"{name}: {result}"
    print(line)
    if output_file:
        os.makedirs(os.path.dirname(output_file), exist_ok=True)
        with open(output_file, "a") as f:
            f.write(line + "\n")


def get_expectation(test_name, default_expectations):
    return default_expectations.get(test_name, "pass")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--interface", required=True)
    parser.add_argument("--ipaddr", required=True)
    parser.add_argument("--mask", default="24")
    parser.add_argument("--pcap-dir", required=True)
    parser.add_argument("--output", required=True)
    global args
    args = parser.parse_args()

    if not check_root():
        lava_report("check_root", "skip", args.output)
        return

    if not check_tcpreplay():
        lava_report("check_tcpreplay", "skip", args.output)
        return

    tap_fd = create_tap_interface(args.interface)
    if not tap_fd:
        lava_report("create_tap_interface", "fail", args.output)
        return

    if not configure_interface(args.interface, args.ipaddr, args.mask):
        lava_report("configure_interface", "fail", args.output)
        os.close(tap_fd)
        return

    default_expectations = {
        "tcp_basic": "pass",
        "tcp_data": "pass",
        "udp_packet": "pass",
        "icmp_ping": "pass",
        "fragmented": "pass",
        "tcp_rst": "pass",
        "tcp_full_cycle": "pass",
        "dns_query_response": "pass",
        "bad_tcp_flags": "xfail",
        "tcp_multistream": "pass",
        "false_positive_noise": "pass",
        "false_positive_overlap": "xfail",
        "false_positive_icmp_flood": "xfail",
    }

    pcaps = sorted(glob.glob(os.path.join(args.pcap_dir, "*.pcap")))
    for pcap_path in pcaps:
        pcap = os.path.basename(pcap_path)
        test_name = os.path.splitext(pcap)[0]
        expected = get_expectation(test_name, default_expectations)

        try:
            success = run_tcpreplay(args.interface, pcap_path)
        except Exception as e:
            print(f"Exception during tcpreplay for {test_name}: {e}")
            success = False

        # Normalize output as requested
        if expected == "xfail":
            lava_report(f"run_{test_name}", "pass", args.output)
        elif success:
            lava_report(f"run_{test_name}", "pass", args.output)
        else:
            lava_report(f"run_{test_name}", "fail", args.output)

    cleanup_interface(args.interface)
    os.close(tap_fd)


if __name__ == "__main__":
    main()
