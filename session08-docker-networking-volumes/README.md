# Session 8 – Docker Networking & Volumes

All commands were run on Docker Desktop 29 (macOS, Apple Silicon). The full command list is in [`commands.sh`](commands.sh).

## Task 1 – Container networking (Frontend / Backend / Database)

```
 frontend-net        backend-net            db-net
 ┌──────────┐      ┌─────────────┐      ┌───────────┐
 │ frontend │◄────►│   backend   │◄────►│ database  │
 │ (nginx)  │      │   (nginx)   │      │ (mysql)   │
 └──────────┘      └─────────────┘      └───────────┘
```
* 3 user-defined bridge networks: `frontend-net`, `backend-net`, `db-net`.
* **backend** is attached to **two** networks (`backend-net` and `db-net`) and acts as the bridge between frontend and database.
* **frontend** (nginx:alpine), **backend** (nginx:alpine), **database** (mysql:8.4). The password below is a throw-away test value for a local demo.

```text
$ docker network create frontend-net; docker network create backend-net; docker network create db-net
04eb8eb96f7864d3650ae630551a37f70642b63435317a1e641df14fa690b7ae
f9f961adb568ff153debffdf09abc9ab4f19cedc8dc5bc7dff5e08f73dcd6c95
0017df78b81f0c9cf28b54159ba185ab7088bc3b69d9ed5fa095bd923d03a5b9

$ docker network ls --filter name=-net
NETWORK ID     NAME           DRIVER    SCOPE
f9f961adb568   backend-net    bridge    local
0017df78b81f   db-net         bridge    local
04eb8eb96f78   frontend-net   bridge    local

$ docker run -d --name database --network db-net -e MYSQL_ROOT_PASSWORD=rootpass123 -e MYSQL_DATABASE=appdb mysql:8.4 | cut -c1-12
a287e2a73337

$ docker run -d --name backend --network backend-net nginx:alpine | cut -c1-12; docker network connect db-net backend; echo "backend connected to 2nd network"
4996265d5fd8
backend connected to 2nd network

$ docker run -d --name frontend --network frontend-net nginx:alpine | cut -c1-12
46c7ac6cd5a1

$ docker network connect backend-net frontend

$ docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -E "NAMES|frontend|backend|database"
NAMES          IMAGE            STATUS
frontend       nginx:alpine     Up Less than a second
backend        nginx:alpine     Up Less than a second
database       mysql:8.4        Up Less than a second

$ for c in frontend backend database; do echo "== $c"; docker inspect $c | grep -E "\"(backend-net|db-net|frontend-net)\": \{|\"IPAddress\": \"[0-9]" | sed "s/^ *//"; done
== frontend
"backend-net": {
"IPAddress": "172.20.0.3",
"frontend-net": {
"IPAddress": "172.19.0.2",
== backend
"backend-net": {
"IPAddress": "172.20.0.2",
"db-net": {
"IPAddress": "172.21.0.3",
== database
"db-net": {
"IPAddress": "172.21.0.2",

$ echo "--- frontend -> backend (same network backend-net)"; docker exec frontend ping -c 2 backend
--- frontend -> backend (same network backend-net)
PING backend (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.269 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.127 ms

--- backend ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.127/0.198/0.269 ms

$ echo "--- backend -> database (same network db-net)"; docker exec backend ping -c 2 database
--- backend -> database (same network db-net)
PING database (172.21.0.2): 56 data bytes
64 bytes from 172.21.0.2: seq=0 ttl=64 time=0.139 ms
64 bytes from 172.21.0.2: seq=1 ttl=64 time=0.249 ms

--- database ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.139/0.194/0.249 ms

$ echo "--- frontend -> database (no shared network)"; docker exec frontend ping -c 2 -W 2 database
--- frontend -> database (no shared network)
ping: bad address 'database'

$ echo "--- frontend HTTP -> backend"; docker exec frontend wget -qO- http://backend | head -n 4
--- frontend HTTP -> backend
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>

$ echo "--- backend -> MySQL port 3306"; docker exec backend nc -zv database 3306
--- backend -> MySQL port 3306
database (172.21.0.2:3306) open

$ docker exec database mysql -uroot -prootpass123 -e "SHOW DATABASES;" 2>/dev/null
Database
appdb
information_schema
mysql
performance_schema
sys

$ docker network inspect backend-net -f "{{range .Containers}}{{.Name}} {{end}}"; docker network inspect db-net -f "{{range .Containers}}{{.Name}} {{end}}"
frontend backend 
backend database
```
**Result:**
* frontend → backend ✅ (shared `backend-net`), backend → database ✅ (shared `db-net`, MySQL port 3306 open, `SHOW DATABASES` works).
* frontend → database ❌ `bad address 'database'` – no shared network, so Docker's DNS cannot even resolve it. This is **network isolation**: the database is not reachable from the frontend.
* On user-defined networks, containers resolve each other **by name** (built-in DNS).

## Task 2 – Host network (Apache2)
```text
$ docker pull -q httpd:2.4
docker.io/library/httpd:2.4

$ docker run -d --name apache-host --network host httpd:2.4 | cut -c1-12; sleep 3; docker inspect -f "NetworkMode={{.HostConfig.NetworkMode}}" apache-host
d11e2f86ae42
NetworkMode=host

$ echo "--- reach Apache from another container that also uses the host network:"; docker run --rm --network host curlimages/curl -s localhost:80
--- reach Apache from another container that also uses the host network:
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
<body>
<p>It works!</p>
</body>
</html>

$ docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}" | grep -E "NAMES|apache-host"
NAMES          IMAGE            PORTS                                         STATUS
apache-host    httpd:2.4                                                      Up 12 seconds
```
**Result:** With `--network host` the container has *no network namespace of its own* and no port mapping (`PORTS` column is empty). Apache listens directly on the host's port **80**, and the page "It works!" is returned.
> **Note (Docker Desktop on macOS):** the "host" is Docker Desktop's Linux VM, not the Mac, so `curl localhost:80` from the Mac terminal does not reach it unless *Settings → Resources → Network → Enable host networking* is turned on. I therefore verified port 80 from a second container using the host network. On a Linux server, `http://<server-ip>:80` works directly.

## Task 3 – Bind mount
```text
$ cat /tmp/web-content/index.html
Hello students

$ docker run -d --name nginx-bind -p 8081:80 -v /tmp/web-content:/usr/share/nginx/html nginx:alpine | cut -c1-12; sleep 2; curl -s localhost:8081
1a64dcf65fe1
Hello students

$ echo "Hello students - this file was modified on the host!" > /tmp/web-content/index.html; sleep 3; curl -s localhost:8081
Hello students - this file was modified on the host!

$ docker inspect -f "{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{end}}" nginx-bind; docker ps --filter name=nginx-bind --format "{{.Names}} {{.Status}}"
bind /tmp/web-content -> /usr/share/nginx/html
nginx-bind Up 5 seconds
```
**Result:** The host folder `/tmp/web-content` is mounted into `/usr/share/nginx/html`. After editing `index.html` on the host, the new content was served **without restarting the container** (`Up` status unchanged) – bind mounts share the live host files.

## Task 4 – Overlay networks (research)

**What it is:** An *overlay network* is a virtual network built **on top of** the real network that connects containers running on **different Docker hosts** as if they were on one LAN. Driver: `overlay` (needs Docker Swarm mode or a key-value store).

**How it works across hosts:**
1. Each host runs Docker; hosts are joined in a Swarm (`docker swarm init` / `docker swarm join`).
2. `docker network create -d overlay my-overlay` creates the network on the manager and is extended to nodes when a task needs it.
3. Docker uses **VXLAN** (UDP port 4789) to encapsulate container Ethernet frames inside normal UDP packets between hosts, with a VTEP on each host. Control-plane traffic uses ports 7946 (TCP/UDP) and 2377 (TCP, Swarm management).
4. Containers get IPs from the overlay subnet (e.g. `10.0.1.x`) and can reach each other by IP or service name through Docker's built-in DNS. Optional `--opt encrypted` encrypts the VXLAN data with IPsec.

| Driver | Scope | Use case |
|---|---|---|
| bridge | single host | default for standalone containers |
| host | single host | no isolation, best performance |
| none | single host | fully isolated |
| overlay | **multi-host** | Swarm services, microservices spread over several servers |
| macvlan | single host | container gets its own MAC/IP on the physical LAN |

**Use cases:** multi-host microservices, Swarm service-to-service traffic, load-balanced services (routing mesh), secure (encrypted) east-west traffic. In Kubernetes the equivalent role is played by CNI plugins (Flannel/Calico/Cilium).

```bash
docker swarm init
docker network create -d overlay --attachable my-overlay
docker service create --name web --network my-overlay --replicas 3 nginx
```
