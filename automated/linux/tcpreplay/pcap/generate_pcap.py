#!/usr/bin/env python3
# vim: set ts=8 sw=4 sts=4 et tw=80 fileencoding=utf-8 :
from scapy.all import (
    Ether,
    IP,
    TCP,
    UDP,
    ICMP,
    DNS,
    DNSQR,
    DNSRR,
    wrpcap,
    Raw,
    fragment,
)


test_expectations = {
    "tcp_basic.pcap": "pass",
    "tcp_data.pcap": "pass",
    "udp_packet.pcap": "pass",
    "icmp_ping.pcap": "pass",
    "fragmented.pcap": "pass",
    "tcp_rst.pcap": "pass",
    "tcp_full_cycle.pcap": "pass",
    "dns_query_response.pcap": "pass",
    "bad_tcp_flags.pcap": "xfail",
    "tcp_multistream.pcap": "pass",
    "false_positive_noise.pcap": "pass",
    "false_positive_overlap.pcap": "pass",
    "false_positive_icmp_flood.pcap": "xfail",
}


def tcp_basic():
    ip = IP(src="10.0.0.2", dst="10.0.0.1")
    tcp_syn = TCP(sport=12345, dport=80, flags="S", seq=1000)
    tcp_synack = TCP(sport=80, dport=12345, flags="SA", seq=2000, ack=1001)
    tcp_ack = TCP(sport=12345, dport=80, flags="A", seq=1001, ack=2001)
    wrpcap(
        "pcap/tcp_basic.pcap",
        [Ether() / ip / tcp_syn, Ether() / ip / tcp_synack, Ether() / ip / tcp_ack],
    )


def tcp_data():
    ip = IP(src="10.0.0.2", dst="10.0.0.1")
    tcp = TCP(sport=12345, dport=80, flags="PA", seq=1, ack=1)
    data = Raw(load="GET / HTTP/1.1\r\nHost: test\r\n\r\n")
    wrpcap("pcap/tcp_data.pcap", [Ether() / ip / tcp / data])


def udp_packet():
    ip = IP(src="10.0.0.2", dst="10.0.0.1")
    udp = UDP(sport=1234, dport=1234)
    wrpcap("pcap/udp_packet.pcap", [Ether() / ip / udp / Raw(load="hello")])


def icmp_ping():
    ip = IP(src="10.0.0.2", dst="10.0.0.1")
    wrpcap(
        "pcap/icmp_ping.pcap",
        [
            Ether() / ip / ICMP(type="echo-request") / b"ping",
            Ether() / ip / ICMP(type="echo-reply") / b"pong",
        ],
    )


def fragmented():
    pkt = IP(dst="10.0.0.1") / UDP(sport=1111, dport=2222) / Raw(load="X" * 3000)
    frags = fragment(pkt, fragsize=500)
    wrpcap("pcap/fragmented.pcap", [Ether() / f for f in frags])


def tcp_rst():
    ip = IP(src="10.0.0.2", dst="10.0.0.1")
    rst = TCP(sport=12345, dport=80, flags="R", seq=1234)
    wrpcap("pcap/tcp_rst.pcap", [Ether() / ip / rst])


def tcp_full_cycle():
    eth = Ether(src="00:11:22:33:44:55", dst="66:77:88:99:aa:bb")
    ip = IP(src="10.0.0.2", dst="10.0.0.1")
    packets = [
        eth / ip / TCP(sport=12345, dport=80, flags="S", seq=1000),
        eth / ip / TCP(sport=80, dport=12345, flags="SA", seq=2000, ack=1001),
        eth / ip / TCP(sport=12345, dport=80, flags="A", seq=1001, ack=2001),
        eth
        / ip
        / TCP(sport=12345, dport=80, flags="PA", seq=1001, ack=2001)
        / b"GET / HTTP/1.1\r\nHost: test\r\n\r\n",
        eth
        / ip
        / TCP(sport=80, dport=12345, flags="PA", seq=2001, ack=1025)
        / b"HTTP/1.1 200 OK\r\r\nHi!",
        eth / ip / TCP(sport=12345, dport=80, flags="FA", seq=1025, ack=2024),
        eth / ip / TCP(sport=80, dport=12345, flags="FA", seq=2024, ack=1026),
        eth / ip / TCP(sport=12345, dport=80, flags="A", seq=1026, ack=2025),
    ]
    wrpcap("pcap/tcp_full_cycle.pcap", packets)


def dns_query_response():
    eth = Ether()
    ip = IP(src="10.0.0.2", dst="8.8.8.8")
    query = UDP(sport=1234, dport=53) / DNS(
        id=0xAAAA, qr=0, qd=DNSQR(qname="example.com")
    )
    reply = UDP(sport=53, dport=1234) / DNS(
        id=0xAAAA,
        qr=1,
        qd=DNSQR(qname="example.com"),
        an=DNSRR(rrname="example.com", rdata="93.184.216.34"),
    )
    wrpcap("pcap/dns_query_response.pcap", [eth / ip / query, eth / ip / reply])


def bad_tcp_flags():
    tcp = TCP(sport=1234, dport=80, flags="FPU", seq=1000)
    pkt = Ether() / IP(src="10.0.0.2", dst="10.0.0.1") / tcp
    pkt[TCP].chksum = 0xFFFF  # Force bad checksum
    wrpcap("pcap/bad_tcp_flags.pcap", [pkt])


def tcp_multistream():
    eth = Ether()
    streams = []
    for i in range(3):
        sport = 10000 + i
        dst_port = 80
        ip = IP(src="10.0.0.2", dst="10.0.0.1")
        syn = TCP(sport=sport, dport=dst_port, flags="S", seq=1000 + i)
        ack = TCP(sport=sport, dport=dst_port, flags="A", seq=1001 + i, ack=2001 + i)
        data = (
            TCP(sport=sport, dport=dst_port, flags="PA", seq=1001 + i, ack=2001 + i)
            / f"GET /stream{i}".encode()
        )
        streams.extend([eth / ip / syn, eth / ip / ack, eth / ip / data])
    wrpcap("pcap/tcp_multistream.pcap", streams)


def false_positive_noise():
    packets = []
    for i in range(10):
        pkt = (
            Ether()
            / IP(src=f"192.168.0.{i+10}", dst="10.0.0.1")
            / UDP(sport=1234 + i, dport=5678)
            / Raw(load="NOISE")
        )
        packets.append(pkt)
    wrpcap("pcap/false_positive_noise.pcap", packets)


def false_positive_overlap():
    packets = []
    for i in range(3):
        ip = IP(src=f"10.0.0.{i+3}", dst="10.0.0.1")
        tcp = TCP(sport=1000 + i, dport=80, flags="PA", seq=42 + i, ack=1) / Raw(
            load=f"benign{i}"
        )
        packets.append(Ether() / ip / tcp)
    wrpcap("pcap/false_positive_overlap.pcap", packets)


def false_positive_icmp_flood():
    packets = [
        Ether()
        / IP(src="1.2.3.4", dst="10.0.0.1")
        / ICMP(type="echo-request")
        / Raw(load="flood")
        for _ in range(20)
    ]
    wrpcap("pcap/false_positive_icmp_flood.pcap", packets)


def run_all():
    import os

    os.makedirs("pcap", exist_ok=True)
    tcp_basic()
    tcp_data()
    udp_packet()
    icmp_ping()
    fragmented()
    tcp_rst()
    tcp_full_cycle()
    dns_query_response()
    bad_tcp_flags()
    tcp_multistream()
    false_positive_noise()
    false_positive_overlap()
    false_positive_icmp_flood()
    print("All .pcap files generated in ./pcap/")


if __name__ == "__main__":
    run_all()
