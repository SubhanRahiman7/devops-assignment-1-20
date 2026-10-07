run() { echo "\$ $*"; bash -c "$*" 2>&1; echo; }
docker rm -f frontend backend database apache-host nginx-bind >/dev/null 2>&1
docker network rm frontend-net backend-net db-net >/dev/null 2>&1
echo "##### T1"
run 'docker network create frontend-net; docker network create backend-net; docker network create db-net'
run 'docker network ls --filter name=-net'
run 'docker run -d --name database --network db-net -e MYSQL_ROOT_PASSWORD=rootpass123 -e MYSQL_DATABASE=appdb mysql:8.4 | cut -c1-12'
run 'docker run -d --name backend --network backend-net nginx:alpine | cut -c1-12; docker network connect db-net backend; echo "backend connected to 2nd network"'
run 'docker run -d --name frontend --network frontend-net nginx:alpine | cut -c1-12'
run 'docker network connect backend-net frontend'
run 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | grep -E "NAMES|frontend|backend|database"'
run 'for c in frontend backend database; do echo "== $c"; docker inspect $c | grep -E "\"(backend-net|db-net|frontend-net)\": \{|\"IPAddress\": \"[0-9]" | sed "s/^ *//"; done'
sleep 25
run 'echo "--- frontend -> backend (same network backend-net)"; docker exec frontend ping -c 2 backend'
run 'echo "--- backend -> database (same network db-net)"; docker exec backend ping -c 2 database'
run 'echo "--- frontend -> database (no shared network)"; docker exec frontend ping -c 2 -W 2 database'
run 'echo "--- frontend HTTP -> backend"; docker exec frontend wget -qO- http://backend | head -n 4'
run 'echo "--- backend -> MySQL port 3306"; docker exec backend nc -zv database 3306'
run 'docker exec database mysql -uroot -prootpass123 -e "SHOW DATABASES;" 2>/dev/null'
run 'docker network inspect backend-net -f "{{range .Containers}}{{.Name}} {{end}}"; docker network inspect db-net -f "{{range .Containers}}{{.Name}} {{end}}"'
echo "##### T2"
run 'docker pull -q httpd:2.4'
run 'docker run -d --name apache-host --network host httpd:2.4 | cut -c1-12; sleep 3; docker inspect -f "NetworkMode={{.HostConfig.NetworkMode}}" apache-host'
run 'echo "--- reach Apache from another container that also uses the host network:"; docker run --rm --network host curlimages/curl -s localhost:80'
run 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}" | grep -E "NAMES|apache-host"'
echo "##### T3"
rm -rf /tmp/web-content && mkdir /tmp/web-content && echo "Hello students" > /tmp/web-content/index.html
run 'cat /tmp/web-content/index.html'
run 'docker run -d --name nginx-bind -p 8081:80 -v /tmp/web-content:/usr/share/nginx/html nginx:alpine | cut -c1-12; sleep 2; curl -s localhost:8081'
run 'echo "Hello students - this file was modified on the host!" > /tmp/web-content/index.html; sleep 3; curl -s localhost:8081'
run 'docker inspect -f "{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{end}}" nginx-bind; docker ps --filter name=nginx-bind --format "{{.Names}} {{.Status}}"'
