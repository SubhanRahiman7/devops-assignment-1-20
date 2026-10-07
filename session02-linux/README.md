# Session 2 – Linux Homework

> All commands were executed on a real **Ubuntu 24.04 LTS** system (a systemd-enabled Docker container, `ubuntu-systemd`, run on macOS/Apple Silicon) because macOS has no `adduser`, `useradd` or `journalctl`. Outputs below are copied from that terminal.

## Task 1 – Soft Link & Hard Link

### Concepts
| | Hard link | Soft (symbolic) link |
|---|---|---|
| What it is | Another **name** for the same inode (same data on disk) | A small file that stores the **path** to another file (like a shortcut) |
| Command | `ln target linkname` | `ln -s target linkname` |
| Inode | Same inode as the original | Its own, different inode |
| If original is deleted | Link still works (data stays until the link count reaches 0) | Link **breaks** (dangling link) |
| Works across file systems | No | Yes |
| Can link directories | No | Yes |
| Size | Same as original | Length of the path string |

**Interview answer:** A hard link is a second directory entry pointing to the same inode, so the file's data survives as long as at least one hard link exists. A soft link is a separate file containing a path; if the target is removed or moved, the soft link is broken.

### Commands: create, inspect, delete
```text
$ echo "Hello DevOps" > original.txt; ls -li
total 4
81256 -rw-r--r-- 1 root root 13 Oct  7 16:35 original.txt

$ ln original.txt hardlink.txt

$ ln -s original.txt softlink.txt

$ ls -li
total 8
81256 -rw-r--r-- 2 root root 13 Oct  7 16:35 hardlink.txt
81256 -rw-r--r-- 2 root root 13 Oct  7 16:35 original.txt
81257 lrwxrwxrwx 1 root root 12 Oct  7 16:35 softlink.txt -> original.txt

$ cat hardlink.txt softlink.txt
Hello DevOps
Hello DevOps

$ stat -c "%n links=%h inode=%i" original.txt hardlink.txt softlink.txt
original.txt links=2 inode=81256
hardlink.txt links=2 inode=81256
softlink.txt links=1 inode=81257

$ rm original.txt; ls -li
total 4
81256 -rw-r--r-- 1 root root 13 Oct  7 16:35 hardlink.txt
81257 lrwxrwxrwx 1 root root 12 Oct  7 16:35 softlink.txt -> original.txt

$ echo "--- hard link still works:"; cat hardlink.txt; echo "--- soft link now dangling:"; cat softlink.txt
--- hard link still works:
Hello DevOps
--- soft link now dangling:
cat: softlink.txt: No such file or directory

$ readlink softlink.txt; ls -l softlink.txt
original.txt
lrwxrwxrwx 1 root root 12 Oct  7 16:35 softlink.txt -> original.txt

$ rm softlink.txt hardlink.txt; ls -li
total 0
```
**Observation:** `original.txt` and `hardlink.txt` share inode `81256` and the link count is 2. `softlink.txt` has its own inode and shows `-> original.txt`. After `rm original.txt` the hard link still printed the content, but the soft link failed with *No such file or directory*.

## Task 2 – `adduser` vs `useradd`

| | `useradd` | `adduser` |
|---|---|---|
| Type | Low-level binary (ELF) from the `shadow` package | High-level **Perl script** (Debian/Ubuntu) that calls `useradd` |
| Home directory | **Not** created unless `-m` is given | Created automatically and `/etc/skel` files are copied |
| Password | Not set (account locked `!`) – must run `passwd` | Interactive: asks for password and user details |
| Default shell | `/bin/sh` | `/bin/bash` |
| Group | Depends on `/etc/login.defs` | Creates a matching group and adds to `users` |
| Portable across distros | Yes (all Linux) | Debian/Ubuntu only (on RHEL it is just a symlink to useradd) |

**Preferred on Ubuntu: `adduser`** – it is interactive and friendly, sets up the home directory, skeleton files, group, shell and password in one step. `useradd` is preferred in **scripts/automation** where you need full control with flags (`useradd -m -s /bin/bash -G sudo name`).

```text
$ sudo useradd testuser1; grep testuser1 /etc/passwd; ls -ld /home/testuser1; getent shadow testuser1 | cut -d: -f1,2
testuser1:x:1001:1001::/home/testuser1:/bin/sh
ls: cannot access '/home/testuser1': No such file or directory
testuser1:!

$ sudo adduser --disabled-password --gecos "Test User Two" testuser2
info: Adding user `testuser2' ...
info: Selecting UID/GID from range 1000 to 59999 ...
info: Adding new group `testuser2' (1002) ...
info: Adding new user `testuser2' (1002) with group `testuser2 (1002)' ...
info: Creating home directory `/home/testuser2' ...
info: Copying files from `/etc/skel' ...
info: Adding new user `testuser2' to supplemental / extra groups `users' ...
info: Adding user `testuser2' to group `users' ...

$ grep testuser2 /etc/passwd; ls -ld /home/testuser2; ls -a /home/testuser2; id testuser2
testuser2:x:1002:1002:Test User Two,,,:/home/testuser2:/bin/bash
drwxr-x--- 2 testuser2 testuser2 4096 Oct  7 16:36 /home/testuser2
.
..
.bash_logout
.bashrc
.profile
uid=1002(testuser2) gid=1002(testuser2) groups=1002(testuser2),100(users)

$ sudo userdel -r testuser1; sudo deluser --remove-home testuser2; grep -c testuser /etc/passwd
userdel: testuser1 mail spool (/var/mail/testuser1) not found
userdel: testuser1 home directory (/home/testuser1) not found
info: Looking for files to backup/remove ...
info: Removing files ...
warn: `/usr/bin/crontab' not executed. Skipping crontab removal. Package `cron' required.
info: Removing user `testuser2' ...
0

$ file -L $(which adduser) | cut -c1-90; file -L $(which useradd) | cut -c1-90
/usr/sbin/adduser: Perl script text executable
/usr/sbin/useradd: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamical
```
**Observation:** `useradd testuser1` created the account but **no home directory** (`ls: cannot access '/home/testuser1'`), shell `/bin/sh`, and password field `!` (locked). `adduser testuser2` created `/home/testuser2` with `.bashrc`, `.profile`, shell `/bin/bash`, and its own group. `file` shows `adduser` is a Perl script while `useradd` is a compiled ELF binary. Test users were removed afterwards (`userdel -r`, `deluser --remove-home`).

## Task 3 – `journalctl`

`journalctl` reads the **systemd journal** – the centralized, binary log store collected by `systemd-journald` from the kernel, services, and `logger`. It replaces searching many files in `/var/log`.

| Command | Meaning |
|---|---|
| `journalctl` | All logs (oldest first) |
| `journalctl -u nginx` | Logs of one service (unit) |
| `journalctl -f` | Follow live (like `tail -f`) |
| `journalctl -n 20` | Last 20 lines |
| `journalctl -b` | Current boot only (`-b -1` = previous boot) |
| `journalctl -k` | Kernel messages |
| `journalctl -p err` | Priority error and worse |
| `journalctl --since "1 hour ago" --until now` | Time window |
| `journalctl -o json-pretty` | Output format |
| `journalctl -r` | Newest first |
| `journalctl --disk-usage` | Space used by the journal |

```text
$ systemctl start nginx; systemctl is-active nginx
active

$ journalctl -u nginx --no-pager
Oct 07 16:35:09 d8030a91edf4 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Oct 07 16:35:09 d8030a91edf4 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.

$ journalctl -u nginx -n 3 --no-pager
Oct 07 16:35:09 d8030a91edf4 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Oct 07 16:35:09 d8030a91edf4 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.

$ systemctl restart nginx; journalctl -u nginx --since "1 minute ago" --no-pager
Oct 07 16:35:09 d8030a91edf4 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Oct 07 16:35:09 d8030a91edf4 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
Oct 07 16:35:30 d8030a91edf4 systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...
Oct 07 16:35:30 d8030a91edf4 systemd[1]: nginx.service: Deactivated successfully.
Oct 07 16:35:30 d8030a91edf4 systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
Oct 07 16:35:30 d8030a91edf4 systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Oct 07 16:35:30 d8030a91edf4 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.

$ journalctl -p err --no-pager | tail -n 3; echo "(exit $?)"
Oct 07 16:35:30 d8030a91edf4 deluser[207]: In order to use the --remove-home, --remove-all-files, and --backup features, you need to install the `perl' package. To accomplish that, run apt-get install perl.
(exit 0)

$ journalctl -b --no-pager | head -n 5
Oct 07 16:35:09 d8030a91edf4 kernel: Booting Linux on physical CPU 0x0000000000 [0x610f0000]
Oct 07 16:35:09 d8030a91edf4 kernel: Linux version 6.12.54-linuxkit (root@buildkitsandbox) (gcc (Alpine 13.2.1_git20240309) 13.2.1 20240309, GNU ld (GNU Binutils) 2.42) #1 SMP Tue Nov  4 21:21:47 UTC 2025
Oct 07 16:35:09 d8030a91edf4 kernel: OF: reserved mem: Reserved memory: No reserved-memory node in the DT
Oct 07 16:35:09 d8030a91edf4 kernel: Zone ranges:
Oct 07 16:35:09 d8030a91edf4 kernel:   DMA      [mem 0x0000000070000000-0x00000000ffffffff]

$ journalctl -k --no-pager | head -n 3
Oct 07 16:35:09 d8030a91edf4 kernel: Booting Linux on physical CPU 0x0000000000 [0x610f0000]
Oct 07 16:35:09 d8030a91edf4 kernel: Linux version 6.12.54-linuxkit (root@buildkitsandbox) (gcc (Alpine 13.2.1_git20240309) 13.2.1 20240309, GNU ld (GNU Binutils) 2.42) #1 SMP Tue Nov  4 21:21:47 UTC 2025
Oct 07 16:35:09 d8030a91edf4 kernel: OF: reserved mem: Reserved memory: No reserved-memory node in the DT

$ journalctl --disk-usage
Archived and active journals take up 8.0M in the file system.

$ journalctl -u nginx -o json-pretty -n 1 --no-pager | head -n 12
{
	"__SEQNUM_ID" : "5baeea87842d43bfa90a05d6d5191312",
	"_EXE" : "/usr/lib/systemd/systemd",
	"MESSAGE" : "Started nginx.service - A high performance web server and a reverse proxy server.",
	"TID" : "1",
	"PRIORITY" : "6",
	"_UID" : "0",
	"_BOOT_ID" : "690ee0b78afe45f8a9ca5ecfa49a1b95",
	"_CMDLINE" : "/lib/systemd/systemd",
	"SYSLOG_IDENTIFIER" : "systemd",
	"_GID" : "0",
	"CODE_FILE" : "src/core/job.c",

$ logger "hello from homework"; journalctl -t root -n 1 --no-pager; journalctl _COMM=systemd -n 1 --no-pager
Oct 07 16:35:30 d8030a91edf4 root[258]: hello from homework
Oct 07 16:35:30 d8030a91edf4 systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
```
**Observation:** After `systemctl restart nginx` the journal for `-u nginx` shows the Stopping → Deactivated → Stopped → Starting → Started sequence, which is how you debug service start-up problems. `-p err` surfaced the earlier `deluser` error message.

## Task 4 – Linux Command Cheat Sheet (practice)

| Category | Commands practised | Purpose |
|---|---|---|
| Navigation | `pwd`, `ls -la`, `cd`, `tree` | Where am I / list / move |
| Files & dirs | `mkdir -p`, `touch`, `cp`, `mv`, `rm`, `cat` | Create, copy, move, delete, read |
| Text | `head`, `tail`, `wc -l`, `grep`, `sort`, `uniq`, `tr` | Inspect and filter text |
| Search | `find`, `which`, `type` | Locate files/commands |
| Permissions | `chmod`, `chown` | Change mode / owner |
| Processes | `ps aux`, `top` | View running processes |
| Disk & memory | `df -h`, `du -sh`, `free -h` | Disk and RAM usage |
| Network | `ip addr`, `ss -tlnp`, `curl -I`, `ping` | Interfaces, ports, HTTP, reachability |
| System | `uname -a`, `uptime`, `hostname`, `/etc/os-release` | System information |
| Archive | `tar -czf`, `tar -tzf` | Compress / list archives |
| Services | `systemctl status` | Service state |
| Shell | `env`, `export`, `echo`, `>`, `>>`, `\|` | Variables, redirection, pipes |

```text
$ pwd; whoami; hostname; uname -a
/tmp/cheat
root
d8030a91edf4
Linux d8030a91edf4 6.12.54-linuxkit #1 SMP Tue Nov  4 21:21:47 UTC 2025 aarch64 aarch64 aarch64 GNU/Linux

$ mkdir -p project/src project/docs; touch project/src/app.py project/docs/readme.txt; tree project
project
|-- docs
|   `-- readme.txt
`-- src
    `-- app.py

3 directories, 2 files

$ ls -la project; cd project/src && pwd
total 16
drwxr-xr-x 4 root root 4096 Oct  7 16:36 .
drwxr-xr-x 3 root root 4096 Oct  7 16:36 ..
drwxr-xr-x 2 root root 4096 Oct  7 16:36 docs
drwxr-xr-x 2 root root 4096 Oct  7 16:36 src
/tmp/cheat/project/src

$ echo "line one" > a.txt; echo "line two" >> a.txt; echo "error: disk full" >> a.txt; cat a.txt
line one
line two
error: disk full

$ cp a.txt b.txt; mv b.txt c.txt; ls; rm c.txt; ls
a.txt
c.txt
project
a.txt
project

$ head -n 1 a.txt; tail -n 1 a.txt; wc -l a.txt
line one
error: disk full
3 a.txt

$ grep -i error a.txt; grep -c line a.txt
error: disk full
2

$ find /tmp/cheat -name "*.py"; find /tmp/cheat -type f | wc -l
/tmp/cheat/project/src/app.py
3

$ chmod 750 a.txt; ls -l a.txt; chmod u+x a.txt; ls -l a.txt; sudo chown nobody:nogroup a.txt; ls -l a.txt
-rwxr-x--- 1 root root 35 Oct  7 16:36 a.txt
-rwxr-x--- 1 root root 35 Oct  7 16:36 a.txt
-rwxr-x--- 1 nobody nogroup 35 Oct  7 16:36 a.txt

$ ps aux | head -n 4; ps -ef | grep -c systemd
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.1  0.1  21356 11732 ?        Ss   16:35   0:00 /lib/systemd/systemd
root          23  0.0  0.1  33696 11632 ?        S<s  16:35   0:00 /usr/lib/systemd/systemd-journald
systemd+      72  0.0  0.1  21300 12532 ?        Ss   16:35   0:00 /usr/lib/systemd/systemd-resolved
7

$ top -b -n 1 | head -n 5
top - 16:36:19 up 2 min,  0 user,  load average: 0.49, 0.18, 0.06
Tasks:  22 total,   1 running,  21 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.0 us,  0.8 sy,  0.0 ni, 97.5 id,  0.8 wa,  0.0 hi,  0.8 si,  0.0 st 
MiB Mem :   7836.6 total,   6221.4 free,    738.6 used,   1072.3 buff/cache     
MiB Swap:   1024.0 total,   1024.0 free,      0.0 used.   7098.0 avail Mem 

$ df -h / | head -n 3; du -sh /tmp/cheat; free -h
Filesystem      Size  Used Avail Use% Mounted on
overlay         453G  8.3G  421G   2% /
20K	/tmp/cheat
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       738Mi       6.1Gi       608Ki       1.0Gi       6.9Gi
Swap:          1.0Gi          0B       1.0Gi

$ ip -br addr; ss -tlnp | head -n 5
lo               UNKNOWN        127.0.0.1/8 ::1/128 
tunl0@NONE       DOWN           
gre0@NONE        DOWN           
gretap0@NONE     DOWN           
erspan0@NONE     DOWN           
ip_vti0@NONE     DOWN           
ip6_vti0@NONE    DOWN           
sit0@NONE        DOWN           
ip6tnl0@NONE     DOWN           
ip6gre0@NONE     DOWN           
eth0@if21        UP             172.17.0.2/16 
State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess                                                                                                                                                                                                                                                                                     
LISTEN 0      4096      127.0.0.54:53        0.0.0.0:*    users:(("systemd-resolve",pid=72,fd=17))                                                                                                                                                                                                                                                   
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=243,fd=5),("nginx",pid=242,fd=5),("nginx",pid=241,fd=5),("nginx",pid=240,fd=5),("nginx",pid=239,fd=5),("nginx",pid=237,fd=5),("nginx",pid=236,fd=5),("nginx",pid=235,fd=5),("nginx",pid=234,fd=5),("nginx",pid=233,fd=5),("nginx",pid=232,fd=5),("nginx",pid=231,fd=5))
LISTEN 0      4096   127.0.0.53%lo:53        0.0.0.0:*    users:(("systemd-resolve",pid=72,fd=15))                                                                                                                                                                                                                                                   
LISTEN 0      511             [::]:80           [::]:*    users:(("nginx",pid=243,fd=6),("nginx",pid=242,fd=6),("nginx",pid=241,fd=6),("nginx",pid=240,fd=6),("nginx",pid=239,fd=6),("nginx",pid=237,fd=6),("nginx",pid=236,fd=6),("nginx",pid=235,fd=6),("nginx",pid=234,fd=6),("nginx",pid=233,fd=6),("nginx",pid=232,fd=6),("nginx",pid=231,fd=6))

$ curl -sI http://localhost | head -n 3; ping -c 2 127.0.0.1 | tail -n 3
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Wed, 07 Oct 2026 16:36:19 GMT
--- 127.0.0.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1027ms
rtt min/avg/max/mdev = 0.042/0.062/0.083/0.020 ms

$ cat /etc/os-release | head -n 3; uptime
PRETTY_NAME="Ubuntu 24.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
 16:36:20 up 2 min,  0 user,  load average: 0.49, 0.18, 0.06

$ ls /etc | head -n 5 | sort -r; echo "b a c" | tr " " "\n" | sort | uniq
bash.bashrc
apt
alternatives
adduser.conf
X11
a
b
c

$ env | grep -E "^(HOME|USER|PATH)="; export MYVAR=devops; echo $MYVAR
HOME=/root
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
devops

$ tar -czf backup.tar.gz project; tar -tzf backup.tar.gz | head -n 3
project/
project/docs/
project/docs/readme.txt

$ systemctl status nginx --no-pager | head -n 4
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-10-07 16:35:30 UTC; 49s ago
       Docs: man:nginx(8)

$ history | tail -n 2; which ls; type cd; alias ll="ls -l"; man --version 2>&1 | head -1
/usr/bin/ls
cd is a shell builtin
This system has been minimized by removing packages and content that are
```
