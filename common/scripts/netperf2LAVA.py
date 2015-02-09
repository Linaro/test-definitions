#!/usr/bin/python
import re
import sys

# Parse netperf/ping/tcpreplay results looking for the data in the form of
# line = "Actual: 113000 packets (7810000 bytes) sent in 4.75 seconds.		Rated: 1644210.5 bps, 12.54 Mbps, 23789.47 pps"
# line = "rtt min/avg/max/mdev = 4.037/4.037/4.037/0.000 ms"
# line = "87380 16384 2048 10.00 4289.48 51.12 51.12 3.905 3.905" ./netperf -l 10 -c -C -- -m 2048 -D
# line = "180224    8192   10.00     1654855      0    10845.1     52.60    1.589" ./netperf -t UDP_STREAM -l 10 -c -C -- -m 8192 -D
# line = "180224           10.00     1649348           10809.0     52.60    1.589" rcv side of UDP_STREAM
# line = "16384  87380  1       1      10.00   47469.68  29.84  29.84  25.146  25.146" ./netperf -t TCP_RR -l 10 -c -C -- -r 1,1

found_result = "false"
parser_replay = re.compile("Rated:\s+(?P<throughput1>\d+\.\d+)\s+\S+\s+(?P<throughput2>\d+\.\d+)\s+\S+\s+(?P<throughput3>\d+\.\d+)")
parser_rtt = re.compile("^rtt\s+\S+\s+\=\s+(?P<min>\d+\.\d+)\/(?P<avg>\d+\.\d+)\/(?P<max>\d+\.\d+)\/(?P<mdev>\d+\.\d+)")
parser_tcp = re.compile("^\s*(?P<Recv>\d+)\s+(?P<Send>\d+)\s+(?P<Msg>\d+)\s+(?P<time>\d+\.\d+)\s+(?P<throughput>\d+\.\d+)\s+(?P<cpu_s>\d+\.\d+)\s+(?P<cpu_r>\d+\.\d+)\s+(?P<srv_s>\d+\.\d+)\s+(?P<dem_r>\d+\.\d+)\s*$")
parser_udp_l = re.compile("^\s*(?P<Sock>\d+)\s+(?P<Msg>\d+)\s+(?P<time>\d+\.\d+)\s+(?P<Okey>\d+)\s+(?P<Errs>\d+)\s+(?P<throughput>\d+\.\d+)\s+(?P<cpu_s>\d+\.\d+)\s+(?P<srv_s>\d+\.\d+)\s*$")
parser_udp_r = re.compile("^\s*(?P<Sock>\d+)\s+(?P<time>\d+\.\d+)\s+(?P<Okey>\d+)\s+(?P<throughput>\d+\.\d+)\s+(?P<cpu_r>\d+\.\d+)\s+(?P<srv_r>\d+\.\d+)\s*$")
parser_rr = re.compile("^\s*(?P<Send>\d+)\s+(?P<Recv>\d+)\s+(?P<Req>\d+)\s+(?P<Res>\d+)\s+(?P<time>\d+\.\d+)\s+(?P<trans>\d+\.\d+)\s+(?P<cpu_s>\d+\.\d+)\s+(?P<cpu_r>\d+\.\d+)\s+(?P<srv_s>\d+\.\d+)\s+(?P<dem_r>\d+\.\d+)\s*$")
parser_rr_tcp = re.compile("TCP REQUEST/RESPONSE")
parser_rr_udp = re.compile("UDP REQUEST/RESPONSE")

for line in sys.stdin:
        for parser in [parser_replay, parser_rtt, parser_tcp, parser_udp_l, parser_udp_r, parser_rr, parser_rr_tcp, parser_rr_udp]:
                result = parser.search(line)
                if result is not None:
                        if parser is parser_rr_tcp:
                                rr_type = "TCP_RR"
                                break
                        if parser is parser_rr_udp:
                                rr_type = "UDP_RR"
                                break
                        if parser is parser_replay:
                                print "test_case_id:tcpreplay rated throughput1" + " units:bps " + "measurement:" + result.group('throughput1') + " result:skip"
                                print "test_case_id:tcpreplay rated throughput2" + " units:Mbps " + "measurement:" + result.group('throughput2') + " result:skip"
                                print "test_case_id:tcpreplay rated throughput3" + " units:pps " + "measurement:" + result.group('throughput3') + " result:skip"
                                found_result = "true"
                                break
                        if parser is parser_rtt:
                                print "test_case_id:PING_RTT min" + " units:ms " + "measurement:" + result.group('min') + " result:skip"
                                print "test_case_id:PING_RTT avg" + " units:ms " + "measurement:" + result.group('avg') + " result:skip"
                                print "test_case_id:PING_RTT max" + " units:ms " + "measurement:" + result.group('max') + " result:skip"
                                print "test_case_id:PING_RTT mdev" + " units:ms " + "measurement:" + result.group('mdev') + " result:skip"
                                found_result = "true"
                                break
                        if parser is parser_tcp:
                                print "test_case_id:TCP_STREAM throughput" + "(Msg: " + result.group('Msg') + ")" + " units:10^bits/sec " + "measurement:" + result.group('throughput') + " result:skip"
                                print "test_case_id:TCP_STREAM snd cpu utilization" + "(Msg: " + result.group('Msg') + ")" + " units:% " + "measurement:" + result.group('cpu_s') + " result:skip"
                                print "test_case_id:TCP_STREAM rcv cpu utilization" + "(Msg: " + result.group('Msg') + ")" + " units:% " + "measurement:" + result.group('cpu_r') + " result:skip"
                                found_result = "true"
                                break
                        if parser is parser_udp_l:
                                print "test_case_id:UDP_STREAM snd throughput" + "(Msg: " + result.group('Msg') + ")" + " units:10^bits/sec " + "measurement:" + result.group('throughput') + " result:skip"
                                print "test_case_id:UDP_STREAM snd cpu utilization" + "(Msg: " + result.group('Msg') + ")" + " units:% " + "measurement:" + result.group('cpu_s') + " result:skip"
                                found_result = "true"
                                break
                        if parser is parser_udp_r:
                                print "test_case_id:UDP_STREAM rcv throughput" + " units:10^bits/sec " + "measurement:" + result.group('throughput') + " result:skip"
                                print "test_case_id:UDP_STREAM rcv cpu utilization" + " units:% " + "measurement:" + result.group('cpu_r') + " result:skip"
                                found_result = "true"
                                break
                        if parser is parser_rr:
                                print "test_case_id:" + rr_type + " transaction rate" + "(Req: " + result.group('Req') + " Res: " + result.group('Res') + ")" + " units:trans/sec " + "measurement:" + result.group('trans') + " result:skip"
                                print "test_case_id:" + rr_type + " snd cpu utilization" + "(Req: " + result.group('Req') + " Res: " + result.group('Res') + ")" + " units:% " + "measurement:" + result.group('cpu_s') + " result:skip"
                                print "test_case_id:" + rr_type + " rcv cpu utilization" + "(Req: " + result.group('Req') + " Res: " + result.group('Res') + ")" + " units:% " + "measurement:" + result.group('cpu_r') + " result:skip"
                                found_result = "true"
                                break
                else:
                        continue

if found_result == "false":
        print "units:none " + "measurement:" + "0" + " result:fail"
