# Session 6 – Docker Hello World Applications

Six simple "Hello World" web apps, each in its own folder with application code and a `Dockerfile`. Every image was built and run with Docker and the page response was verified.

| Folder | App | Base image | Access | Response |
|---|---|---|---|---|
| [`nodejs-app`](nodejs-app/) | Node.js (Express) | `node:22-alpine` | http://localhost:3001 → container 3000 | Hello World from Node.js in Docker! |
| [`python-app`](python-app/) | Python (http.server) | `python:3.12-slim` | http://localhost:3002 → container 5000 | Hello World from Python in Docker! |
| [`java-app`](java-app/) | Java 21 (com.sun.net.httpserver, multi-stage) | `eclipse-temurin:21-jdk / 21-jre` | http://localhost:3003 → container 8080 | Hello World from Java in Docker! |
| [`Apache-app`](Apache-app/) | Apache httpd | `httpd:2.4-alpine` | http://localhost:3004 → container 80 | Hello World from Apache (httpd) in Docker! |
| [`React-app`](React-app/) | React 18 + Vite (multi-stage → Nginx) | `node:22-alpine → nginx:alpine` | http://localhost:3005 → container 80 | Hello World from React in Docker! |
| [`nginx-app`](nginx-app/) | Nginx | `nginx:alpine` | http://localhost:3006 → container 80 | Hello World from Nginx in Docker! |

## Commands used (per app)
```bash
docker build -t <image-name> ./<folder>      # build the image from the Dockerfile
docker run -d --name <image-name> -p <host-port>:<container-port> <image-name>   # run detached with port mapping
curl http://localhost:<host-port>            # verify Hello World
docker ps                                    # list running containers
```

## Build + run output
```text
$ docker build -t hello-node ./nodejs-app
#10 naming to docker.io/library/hello-node:latest done
$ docker run -d --name hello-node -p 3001:3000 hello-node
c32556acb4e5

$ docker build -t hello-python ./python-app
#8 naming to docker.io/library/hello-python:latest done
$ docker run -d --name hello-python -p 3002:5000 hello-python
bb8c34b9f3a2

$ docker build -t hello-java ./java-app
#13 naming to docker.io/library/hello-java:latest done
$ docker run -d --name hello-java -p 3003:8080 hello-java
3c1ff608810f

$ docker build -t hello-apache ./Apache-app
#7 naming to docker.io/library/hello-apache:latest done
$ docker run -d --name hello-apache -p 3004:80 hello-apache
2ecdb61a6633

$ docker build -t hello-react ./React-app
#14 naming to docker.io/library/hello-react:latest done
$ docker run -d --name hello-react -p 3005:80 hello-react
19b917c8f715

$ docker build -t hello-nginx ./nginx-app
#7 naming to docker.io/library/hello-nginx:latest done
$ docker run -d --name hello-nginx -p 3006:80 hello-nginx
c8d560962755
```

## Verification – `docker ps`
```text
NAMES          IMAGE            PORTS                                         STATUS
hello-nginx    hello-nginx      0.0.0.0:3006->80/tcp       Up 17 seconds
hello-react    hello-react      0.0.0.0:3005->80/tcp       Up 18 seconds
hello-apache   hello-apache     0.0.0.0:3004->80/tcp       Up 38 seconds
hello-java     hello-java       0.0.0.0:3003->8080/tcp   Up 49 seconds
hello-python   hello-python     0.0.0.0:3002->5000/tcp   Up About a minute
hello-node     hello-node       0.0.0.0:3001->3000/tcp   Up About a minute
```

## Verification – HTTP responses
```text
$ curl localhost:3001   # Node.js
<h1>Hello World from Node.js in Docker!</h1>
$ curl localhost:3002   # Python
<h1>Hello World from Python in Docker!</h1>
$ curl localhost:3003   # Java
<h1>Hello World from Java in Docker!</h1>
$ curl localhost:3004   # Apache
<h1>Hello World from Apache (httpd) in Docker!</h1>
$ curl localhost:3006   # Nginx
<h1>Hello World from Nginx in Docker!</h1>
$ curl localhost:3005   # React (single-page app: HTML shell + JS bundle)
<!doctype html> ... <div id="root"></div> ...
$ curl localhost:3005/assets/index-*.js | grep -o "Hello World from React in Docker!"
Hello World from React in Docker!
```
React renders `<h1>` in the browser with JavaScript, so the text appears inside the bundled JS and on the page at http://localhost:3005.

## Images
```text
REPOSITORY                    TAG         SIZE
hello-nginx                   latest      93MB
hello-react                   latest      93.2MB
hello-apache                  latest      115MB
hello-java                    latest      486MB
hello-python                  latest      203MB
hello-node                    latest      252MB
```

## Dockerfiles

### `nodejs-app/Dockerfile`
```dockerfile
FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY server.js .
EXPOSE 3000
CMD ["npm", "start"]
```

### `python-app/Dockerfile`
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY app.py .
EXPOSE 5000
CMD ["python", "app.py"]
```

### `java-app/Dockerfile`
```dockerfile
# Stage 1: compile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY HelloWorld.java .
RUN javac HelloWorld.java

# Stage 2: run on a small JRE image
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/HelloWorld.class .
EXPOSE 8080
CMD ["java", "HelloWorld"]
```

### `Apache-app/Dockerfile`
```dockerfile
FROM httpd:2.4-alpine
COPY index.html /usr/local/apache2/htdocs/index.html
EXPOSE 80
```

### `React-app/Dockerfile`
```dockerfile
# Stage 1: build the React app
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: serve static files with Nginx
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

### `nginx-app/Dockerfile`
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

## What I learned
* `FROM` selects the base image, `COPY` adds code, `RUN` executes at build time, `CMD` is the start command, `EXPOSE` documents the port.
* `-p host:container` publishes a container port on the host.
* **Multi-stage builds** (Java, React) compile in a big build image and ship only the output in a small runtime image.
