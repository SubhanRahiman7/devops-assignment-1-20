# Session 4 – Networking Homework

> Commands were run on Ubuntu 24.04 (Docker container, bridge network `172.17.0.0/16`) with real internet access. Some values (public IP) are redacted.

## Concepts covered (from class notes)
* **IP address** – unique identifier of a device (IPv4 = 32 bits, `0.0.0.0 – 255.255.255.255`).
* **Classes:** A `1–126` (/8), B `128–191` (/16), C `192–223` (/24), D `224–239` multicast.
* **Subnet mask** separates the network part from the host part. `/8` = 8 network bits + 24 host bits → 2^24 − 2 usable hosts.
* **Private ranges:** `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.

## Commands, output and explanation

| Command | What I understood |
|---|---|
| `hostname`, `hostname -I` | Shows the machine name and all its IP addresses. |
| `ip addr show` | Shows interfaces, IP/mask (`172.17.0.2/16`), MAC address and state. Replaces old `ifconfig`. |
| `ip route` / `netstat -rn` | Routing table. `default via 172.17.0.1` = gateway used for any destination not on the local network. |
| `ip neigh` | ARP table: IP → MAC of neighbours on the LAN. |
| `/etc/resolv.conf`, `/etc/hosts` | DNS server used (`nameserver`) and static name→IP mappings checked before DNS. |
| `ping` | Sends ICMP echo to test reachability and latency (RTT); packet loss % shows connectivity quality. |
| `traceroute` | Lists each router (hop) on the path using increasing TTL. `* * *` = hop does not answer ICMP/UDP probes (common behind NAT/firewalls). |
| `nslookup` / `dig` / `getent hosts` | DNS lookups: name → IP (A record), mail servers (MX). `dig` shows TTL and query time. |
| `curl -I` / `curl -w` | Makes HTTP(S) requests; `-I` only headers, `-w` prints status code and timing. |
| `ss -tuln` / `netstat -tulnp` | Lists listening TCP/UDP ports and the owning process (nginx on 80, DNS resolver on 53). |
| `nc -zv host port` | Port check: `443` succeeded, `81` timed out (closed/filtered). |
| `whois` | Domain registration details. |
| `ip -s link` | Interface statistics: bytes/packets/errors/drops. |

### Output
```text
$ hostname; hostname -I
d8030a91edf4
172.17.0.2 

$ ip addr show eth0
11: eth0@if21: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc noqueue state UP group default 
    link/ether ca:0f:e7:62:d2:52 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever

$ ip route
default via 172.17.0.1 dev eth0 
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.2 

$ ip neigh
172.17.0.1 dev eth0 lladdr 82:c9:8d:6b:1e:53 REACHABLE 

$ cat /etc/resolv.conf | grep -v "^#"

nameserver 192.168.65.7


$ ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=63 time=13.4 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=63 time=12.7 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=63 time=46.5 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=63 time=12.1 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3021ms
rtt min/avg/max/mdev = 12.126/21.176/46.482/14.617 ms

$ ping -c 3 google.com
PING google.com (192.178.174.138) 56(84) bytes of data.
64 bytes from 192.178.174.138: icmp_seq=1 ttl=63 time=29.5 ms
64 bytes from 192.178.174.138: icmp_seq=2 ttl=63 time=31.3 ms
64 bytes from 192.178.174.138: icmp_seq=3 ttl=63 time=28.3 ms

--- google.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 11058ms
rtt min/avg/max/mdev = 28.317/29.691/31.281/1.219 ms

$ traceroute -n -m 6 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 6 hops max, 60 byte packets
 1  172.17.0.1  0.159 ms  0.019 ms  0.020 ms
 2  * * *
 3  * * *
 4  * * *
 5  * * *
 6  * * *

$ nslookup google.com
Server:		192.168.65.7
Address:	192.168.65.7#53

Non-authoritative answer:
Name:	google.com
Address: 192.178.174.138
Name:	google.com
Address: 192.178.174.100
Name:	google.com
Address: 192.178.174.139
Name:	google.com
Address: 192.178.174.102
Name:	google.com
Address: 192.178.174.113
Name:	google.com
Address: 192.178.174.101


$ dig +short google.com A; dig +short MX gmail.com | head -n 2
192.178.174.138
192.178.174.100
192.178.174.139
192.178.174.102
192.178.174.113
192.178.174.101
10 alt1.gmail-smtp-in.l.google.com.
20 alt2.gmail-smtp-in.l.google.com.

$ dig github.com +noall +answer +stats | head -n 6
github.com.		47	IN	A	20.207.73.82
;; Query time: 5 msec
;; SERVER: 192.168.65.7#53(192.168.65.7) (UDP)
;; WHEN: Wed Oct 07 16:37:49 UTC 2026
;; MSG SIZE  rcvd: 54


$ curl -sI https://www.google.com | head -n 5
HTTP/2 200 
content-type: text/html; charset=ISO-8859-1
content-security-policy-report-only: object-src 'none';base-uri 'self';script-src 'nonce-xxxx' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-
accept-ch: Sec-CH-Prefers-Color-Scheme
p3p: CP="This is not a P3P policy! See g.co/p3phelp for more info."

$ curl -s -o /dev/null -w "HTTP %{http_code}, time %{time_total}s\n" https://github.com
HTTP 200, time 0.396237s

$ curl -s https://ifconfig.me; echo
<your-public-ip-redacted>

$ ss -tuln | head -n 6
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
udp   UNCONN 0      0         127.0.0.54:53        0.0.0.0:*          
udp   UNCONN 0      0      127.0.0.53%lo:53        0.0.0.0:*          
tcp   LISTEN 0      4096      127.0.0.54:53        0.0.0.0:*          
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*          
tcp   LISTEN 0      4096   127.0.0.53%lo:53        0.0.0.0:*          

$ netstat -tulnp 2>/dev/null | head -n 5
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 127.0.0.54:53           0.0.0.0:*               LISTEN      72/systemd-resolved 
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      231/nginx: master p 
tcp        0      0 127.0.0.53:53           0.0.0.0:*               LISTEN      72/systemd-resolved 

$ nc -zv github.com 443; nc -zv -w 2 github.com 81
Connection to github.com (20.207.73.82) 443 port [tcp/https] succeeded!
nc: connect to github.com (20.207.73.82) port 81 (tcp) timed out: Operation now in progress

$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG        0 0          0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U         0 0          0 eth0

$ cat /etc/hosts | head -n 4
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::	ip6-localnet
ff00::	ip6-mcastprefix

$ ping -c 2 localhost | head -n 3
PING localhost (::1) 56 data bytes
64 bytes from localhost (::1): icmp_seq=1 ttl=64 time=0.088 ms
64 bytes from localhost (::1): icmp_seq=2 ttl=64 time=0.089 ms

$ whois google.com | grep -iE "^(Domain Name|Registrar:|Creation Date)" | head -n 3
domain names or modify existing registrations. VeriSign reserves the right
Domain Name: google.com
Creation Date: 1997-09-15T07:00:00+0000

$ ip -s link show eth0 | head -n 6
11: eth0@if21: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc noqueue state UP mode DEFAULT group default 
    link/ether ca:0f:e7:62:d2:52 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    RX:  bytes packets errors dropped  missed   mcast           
      46219195    2497      0       0       0       0 
    TX:  bytes packets errors dropped carrier collsns           
        111595    1505      0       0       0       0 

$ getent hosts example.com
104.20.23.154   example.com
172.66.147.243  example.com
```

## Summary
* Local network: container IP `172.17.0.2/16`, gateway `172.17.0.1`.
* Connectivity verified to `8.8.8.8` (0% loss) and DNS resolution works for `google.com` / `github.com`.
* Port 443 on github.com is open; port 81 is not.
