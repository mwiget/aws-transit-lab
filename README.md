# aws-transit-lab

## Problem statement

How can we route traffic via an ec2 instance without sharing routes with AWS? 

## Topology

In order to explore options, the following topology is deployed in AWS using terraform:

```
+--------------------+                          +--------------------+
|      benchr1       |                          |       benchr2      |
|                    |                          |                    |
|   lo 10.10.10.1/32 |        bench_subnet1     |   lo 10.10.10.2/32 |
| eth1 10.0.1.100/24 |--------------------------| eth1 10.0.1.101/24 |
| eth0 10.0.0.150/24 |---                    ---| eth0 10.0.0.151/24 |
+--------------------+   \                  /   +--------------------+
                         |    bench_mgmt    |
                        -+------------------+-
                                  |
                              bench-igw
```

The goal is to be able to ping between both loopback IP address. If successful, this
proofs connectivity for transit traffic via a vpc subnet.


## Solution

The trick is to disable Source/dest check on the ec2 network interfaces and configure routing, static
or dynamic, to point to the next hop interface IP address. 


Using terraform, the sourc/dest check can be disabled via source_dest_check attribute:
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#source_dest_check

Lets have a look at benchr1:

```
mwiget@benchr1:~$ ip a show dev eth1
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
link/ether 02:0c:f6:ca:17:dc brd ff:ff:ff:ff:ff:ff
inet 10.0.1.100/24 brd 10.0.1.255 scope global dynamic eth1
valid_lft 2416sec preferred_lft 2416sec
inet6 fe80::c:f6ff:feca:17dc/64 scope link 
valid_lft forever preferred_lft forever

mwiget@benchr1:~$ ip a show dev lo
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
inet 127.0.0.1/8 scope host lo
valid_lft forever preferred_lft forever
inet 10.10.10.1/32 scope global lo
valid_lft forever preferred_lft forever
inet6 ::1/128 scope host 
valid_lft forever preferred_lft forever

mwiget@benchr1:~$ ip r show
default via 10.0.0.1 dev eth0 proto dhcp src 10.0.0.150 metric 100 
default via 10.0.1.1 dev eth1 proto dhcp src 10.0.1.100 metric 200 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.150 
10.0.0.1 dev eth0 proto dhcp scope link src 10.0.0.150 metric 100 
10.0.1.0/24 dev eth1 proto kernel scope link src 10.0.1.100 
10.0.1.1 dev eth1 proto dhcp scope link src 10.0.1.100 metric 200 
10.10.10.2 via 10.0.1.101 dev eth1 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
```

A static route for 10.10.10.2 points to 10.0.1.101, which is the IP address of eth1 on benchr2. The config on benchr2 looks very
similar:

```
mwiget@benchr2:~$ ip a show dev eth1
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
link/ether 02:e3:39:1d:74:7c brd ff:ff:ff:ff:ff:ff
inet 10.0.1.101/24 brd 10.0.1.255 scope global dynamic eth1
valid_lft 2321sec preferred_lft 2321sec
inet6 fe80::e3:39ff:fe1d:747c/64 scope link 
valid_lft forever preferred_lft forever
mwiget@benchr2:~$ ip a show dev lo
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
inet 127.0.0.1/8 scope host lo
valid_lft forever preferred_lft forever
inet 10.10.10.2/32 scope global lo
valid_lft forever preferred_lft forever
inet6 ::1/128 scope host 
valid_lft forever preferred_lft forever
mwiget@benchr2:~$ ip r show
default via 10.0.0.1 dev eth0 proto dhcp src 10.0.0.151 metric 100 
default via 10.0.1.1 dev eth1 proto dhcp src 10.0.1.101 metric 200 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.151 
10.0.0.1 dev eth0 proto dhcp scope link src 10.0.0.151 metric 100 
10.0.1.0/24 dev eth1 proto kernel scope link src 10.0.1.101 
10.0.1.1 dev eth1 proto dhcp scope link src 10.0.1.101 metric 200 
10.10.10.1 via 10.0.1.100 dev eth1 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
```

## Verification

Run tcpdump on benchr2 eth1 while pinging between loopback IPs from benchr1:

```
mwiget@benchr1:~$ ping 10.10.10.2 -I 10.10.10.1
PING 10.10.10.2 (10.10.10.2) from 10.10.10.1 : 56(84) bytes of data.
64 bytes from 10.10.10.2: icmp_seq=1 ttl=64 time=0.468 ms
64 bytes from 10.10.10.2: icmp_seq=2 ttl=64 time=0.461 ms
^C
--- 10.10.10.2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1019ms
rtt min/avg/max/mdev = 0.461/0.464/0.468/0.003 ms
```

```
mwiget@benchr2:~$ sudo tcpdump -n -i eth1 -e
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
13:20:54.623856 02:e3:39:1d:74:7c > 02:95:2f:f8:49:8a, ethertype ARP (0x0806), length 42: Request who-has 10.0.1.1 tell 10.0.1.101, length 28                                                        
13:20:54.623989 02:95:2f:f8:49:8a > 02:e3:39:1d:74:7c, ethertype ARP (0x0806), length 56: Reply 10.0.1.1 is-at 02:95:2f:f8:49:8a, length 42
13:21:01.550039 02:0c:f6:ca:17:dc > 02:e3:39:1d:74:7c, ethertype IPv4 (0x0800), length 98: 10.10.10.1 > 10.10.10.2: ICMP echo request, id 5, seq 1, length 64
13:21:01.550096 02:e3:39:1d:74:7c > 02:0c:f6:ca:17:dc, ethertype IPv4 (0x0800), length 98: 10.10.10.2 > 10.10.10.1: ICMP echo reply, id 5, seq 1, length 64
13:21:02.568823 02:0c:f6:ca:17:dc > 02:e3:39:1d:74:7c, ethertype IPv4 (0x0800), length 98: 10.10.10.1 > 10.10.10.2: ICMP echo request, id 5, seq 2, length 64
13:21:02.568865 02:e3:39:1d:74:7c > 02:0c:f6:ca:17:dc, ethertype IPv4 (0x0800), length 98: 10.10.10.2 > 10.10.10.1: ICMP echo reply, id 5, seq 2, length 64
```

Bingo!


## Terraform refresh

```
$ terraform refresh

aws_vpc.bench_vpc: Refreshing state... [id=vpc-0fcaa84cf47c98396]
aws_internet_gateway.igw: Refreshing state... [id=igw-0dc557fb6ddc79340]
aws_subnet.bench_subnet1: Refreshing state... [id=subnet-0960a2f1130cdb7ce]
aws_subnet.bench_mgmt: Refreshing state... [id=subnet-0fafd699a1d52f0fb]
aws_security_group.sg: Refreshing state... [id=sg-01960ed17f5e350af]
aws_route_table.rt: Refreshing state... [id=rtb-02a8d603b6140f8e9]
aws_network_interface.bench_benchr2_0: Refreshing state... [id=eni-08b8ad69fe1606d17]
aws_network_interface.bench_benchr1_0: Refreshing state... [id=eni-0a0ef567ff94d3618]
aws_network_interface.benchr1_mgmt: Refreshing state... [id=eni-0a6455e05cacff2d1]
aws_network_interface.bench2_mgmt: Refreshing state... [id=eni-06de73f19da4f82ab]
aws_route_table_association.rt_subnet_asso: Refreshing state... [id=rtbassoc-0f14b535101047306]
aws_eip.one: Refreshing state... [id=eipalloc-0379087c8c95d194c]
aws_eip.two: Refreshing state... [id=eipalloc-0a4373f75f281139c]
aws_instance.benchr1: Refreshing state... [id=i-0ede3ebbc6711206d]
aws_instance.benchr2: Refreshing state... [id=i-090160d810855d6db]

Outputs:

benchr1_public_ip = "13.59.165.169"
benchr1_public_ipv6 = tolist([
  "2600:1f16:4a2:1501:9103:1e02:c1b:ade1",
])
benchr2_public_ip = "3.138.205.225"
benchr2_public_ipv6 = tolist([
  "2600:1f16:4a2:1501:e9b8:45cf:a46:2de",
])
```


