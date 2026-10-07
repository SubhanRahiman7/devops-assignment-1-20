# CoreDNS in Kubernetes

## What is CoreDNS?
CoreDNS is a fast, extensible DNS server written in Go (a CNCF graduated project). In Kubernetes it runs as a Deployment in `kube-system` (exposed by the Service `kube-dns`, ClusterIP `10.96.0.10`) and acts as the **cluster DNS server** for all Pods.

## Why Kubernetes uses CoreDNS
* Pods and Services are ephemeral – IPs change. DNS gives **stable names** (`svc.namespace.svc.cluster.local`).
* Built-in **service discovery** without hard-coding IPs or environment variables.
* Plugin-based (kubernetes, forward, cache, hosts, log, errors, health, prometheus…), lightweight and configurable; it replaced `kube-dns` as default (v1.13).

## How service discovery works
1. A Service is created → the API server stores it and its Endpoints.
2. CoreDNS's **`kubernetes` plugin** watches the API for Services/Endpoints/Pods and answers queries for the `cluster.local` zone from that live data (A/AAAA, SRV, PTR, CNAME for ExternalName).
3. The kubelet writes each Pod's `/etc/resolv.conf` with `nameserver 10.96.0.10`, search domains and `ndots:5`.
4. The Pod resolves `my-svc` → CoreDNS returns the ClusterIP → kube-proxy routes to a Pod.

## How DNS queries are resolved
```
App in Pod ──► resolver (search domains, ndots:5)
           ──► CoreDNS (10.96.0.10)
                 ├─ name ends in cluster.local / in-addr.arpa  → `kubernetes` plugin (answer from API data)
                 ├─ name in `hosts` block                       → static entry (host.minikube.internal)
                 └─ anything else (example.com)                 → `forward . /etc/resolv.conf` → upstream DNS
              (answers cached by the `cache` plugin, except cluster.local in this config)
```
Example from the log below: `10-244-0-113.s11.pod.cluster.local.s11.svc.cluster.local` → **NXDOMAIN** (search domain tried first), then the bare name → **NOERROR**. This is why many `NXDOMAIN` lines for external/long names are normal with `ndots:5`.

## CoreDNS configuration (the Corefile)
Stored in ConfigMap `coredns` (`kubectl -n kube-system edit cm coredns`; the `reload` plugin applies changes).
```text
$ kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
NAME                       READY   STATUS    RESTARTS      AGE   IP           NODE       NOMINATED NODE   READINESS GATES
coredns-559f6c778d-x9kxq   1/1     Running   2 (43m ago)   18d   10.244.0.2   minikube   <none>           <none>

$ kubectl -n kube-system get deploy coredns; kubectl -n kube-system get svc kube-dns
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
coredns   1/1     1            1           18d
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   18d

$ kubectl -n kube-system get cm coredns -o jsonpath="{.data.Corefile}"; echo
.:53 {
    log
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    hosts {
       192.168.65.254 host.minikube.internal
       fallthrough
    }
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30 {
       disable success cluster.local
       disable denial cluster.local
    }
    loop
    reload
    loadbalance
}


$ kubectl -n kube-system get endpoints kube-dns 2>/dev/null
NAME       ENDPOINTS                                     AGE
kube-dns   10.244.0.2:9153,10.244.0.2:53,10.244.0.2:53   18d

$ kubectl -n s11 exec curl-client -- cat /etc/resolv.conf | grep nameserver
nameserver 10.96.0.10

$ kubectl -n kube-system logs -l k8s-app=kube-dns --tail=6
[INFO] 10.244.0.114:36435 - 24161 "A IN 10-244-0-113.s11.pod.cluster.local.s11.svc.cluster.local. udp 74 false 512" NXDOMAIN qr,aa,rd 167 0.0000365s
[INFO] 10.244.0.114:36447 - 45709 "A IN 10-244-0-113.s11.pod.cluster.local.svc.cluster.local. udp 70 false 512" NXDOMAIN qr,aa,rd 163 0.000028541s
[INFO] 10.244.0.114:45626 - 23889 "A IN 10-244-0-113.s11.pod.cluster.local.cluster.local. udp 66 false 512" NXDOMAIN qr,aa,rd 159 0.000030542s
[INFO] 10.244.0.114:52655 - 60688 "A IN 10-244-0-113.s11.pod.cluster.local. udp 52 false 512" NOERROR qr,aa,rd 102 0.000037375s
[INFO] 10.244.0.114:47245 - 59083 "SRV IN _http._tcp.web-service-clusterip.s11.svc.cluster.local. udp 72 false 512" NOERROR qr,aa,rd 248 0.000100542s
[INFO] 10.244.0.114:54195 - 50409 "PTR IN 98.106.110.10.in-addr.arpa. udp 44 false 512" NOERROR qr,aa,rd 127 0.000193083s
```
| Plugin | Purpose |
|---|---|
| `errors`, `log` | print errors / every query |
| `health`, `ready` | liveness (`:8080/health`) and readiness (`:8181/ready`) endpoints |
| `kubernetes cluster.local …` | answers Service/Pod names from the API; `pods insecure`, `ttl 30` |
| `hosts` | static host entries |
| `prometheus :9153` | metrics |
| `forward . /etc/resolv.conf` | send non-cluster names to the node's upstream resolver |
| `cache 30` | cache answers 30 s |
| `loop`, `reload`, `loadbalance` | detect forwarding loops, hot-reload config, randomise A records |

Custom example (stub domain / forward a company domain):
```
corp.example.com:53 {
    errors
    cache 30
    forward . 10.1.2.3
}
```

## How to troubleshoot DNS issues
Checklist (top-down):
1. **Is CoreDNS running?** `kubectl -n kube-system get pods -l k8s-app=kube-dns` and `get svc,endpoints kube-dns`.
2. **Test from a Pod:** `kubectl exec <pod> -- nslookup kubernetes.default` / `getent hosts <svc>` (busybox `nslookup` does not use search domains – use the FQDN).
3. **Check the Pod's `/etc/resolv.conf`:** nameserver should be the `kube-dns` ClusterIP; check `dnsPolicy`.
4. **Read CoreDNS logs:** `kubectl -n kube-system logs -l k8s-app=kube-dns` (enable the `log` plugin).
5. **Does the Service have endpoints?** DNS can resolve but the connection fails if the selector doesn't match: `kubectl get endpoints <svc>`.
6. **Namespace / name:** a short name only works in the same namespace – use `svc.namespace`.
7. **External names fail?** check `forward` and the node's upstream resolver; test `nslookup example.com`.
8. **Corefile errors / loops:** `kubectl -n kube-system describe cm coredns`, look for `loop` crashes.
9. **NetworkPolicy / CNI** blocking UDP/TCP 53 to CoreDNS.

| Symptom | Likely cause |
|---|---|
| `NXDOMAIN` | wrong name / wrong namespace / service doesn't exist |
| `connection refused` / `timed out` to 10.96.0.10 | CoreDNS down, no endpoints, or NetworkPolicy blocking port 53 |
| resolves, but app can't connect | Service has no endpoints / wrong `targetPort` |
| external names fail only | upstream `forward` problem |
| slow lookups | `ndots:5` expansion – use FQDN with trailing dot |

## Hands-on (executed on Minikube): CoreDNS Pod, Service, Corefile, endpoints, logs
```text
$ kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
NAME                       READY   STATUS    RESTARTS      AGE   IP           NODE       NOMINATED NODE   READINESS GATES
coredns-559f6c778d-x9kxq   1/1     Running   2 (43m ago)   18d   10.244.0.2   minikube   <none>           <none>

$ kubectl -n kube-system get deploy coredns; kubectl -n kube-system get svc kube-dns
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
coredns   1/1     1            1           18d
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   18d

$ kubectl -n kube-system get cm coredns -o jsonpath="{.data.Corefile}"; echo
.:53 {
    log
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    prometheus :9153
    hosts {
       192.168.65.254 host.minikube.internal
       fallthrough
    }
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30 {
       disable success cluster.local
       disable denial cluster.local
    }
    loop
    reload
    loadbalance
}


$ kubectl -n kube-system get endpoints kube-dns 2>/dev/null
NAME       ENDPOINTS                                     AGE
kube-dns   10.244.0.2:9153,10.244.0.2:53,10.244.0.2:53   18d

$ kubectl -n s11 exec curl-client -- cat /etc/resolv.conf | grep nameserver
nameserver 10.96.0.10

$ kubectl -n kube-system logs -l k8s-app=kube-dns --tail=6
[INFO] 10.244.0.114:36435 - 24161 "A IN 10-244-0-113.s11.pod.cluster.local.s11.svc.cluster.local. udp 74 false 512" NXDOMAIN qr,aa,rd 167 0.0000365s
[INFO] 10.244.0.114:36447 - 45709 "A IN 10-244-0-113.s11.pod.cluster.local.svc.cluster.local. udp 70 false 512" NXDOMAIN qr,aa,rd 163 0.000028541s
[INFO] 10.244.0.114:45626 - 23889 "A IN 10-244-0-113.s11.pod.cluster.local.cluster.local. udp 66 false 512" NXDOMAIN qr,aa,rd 159 0.000030542s
[INFO] 10.244.0.114:52655 - 60688 "A IN 10-244-0-113.s11.pod.cluster.local. udp 52 false 512" NOERROR qr,aa,rd 102 0.000037375s
[INFO] 10.244.0.114:47245 - 59083 "SRV IN _http._tcp.web-service-clusterip.s11.svc.cluster.local. udp 72 false 512" NOERROR qr,aa,rd 248 0.000100542s
[INFO] 10.244.0.114:54195 - 50409 "PTR IN 98.106.110.10.in-addr.arpa. udp 44 false 512" NOERROR qr,aa,rd 127 0.000193083s
```
### Troubleshooting experiments
```text
$ echo "--- 1 NXDOMAIN for a non-existing service:"; kubectl -n s11 exec curl-client -- nslookup does-not-exist.s11.svc.cluster.local | tail -n 3
--- 1 NXDOMAIN for a non-existing service:
command terminated with exit code 1

** server can't find does-not-exist.s11.svc.cluster.local: NXDOMAIN


$ echo "--- 2 service with no endpoints (selector mismatch) still resolves but connection fails:"; kubectl -n s11 create service clusterip ghost --tcp=80:80; kubectl -n s11 get endpoints ghost 2>/dev/null; kubectl -n s11 exec curl-client -- curl -s -m 3 -o /dev/null -w "HTTP %{http_code}\n" http://ghost || true; kubectl -n s11 delete svc ghost
--- 2 service with no endpoints (selector mismatch) still resolves but connection fails:
service/ghost created
NAME    ENDPOINTS   AGE
ghost   <none>      0s
HTTP 000
command terminated with exit code 7
service "ghost" deleted from s11 namespace

$ echo "--- 3 scale CoreDNS to 0 -> DNS outage:"; kubectl -n kube-system scale deploy coredns --replicas=0; sleep 6; kubectl -n s11 exec curl-client -- nslookup -timeout=2 web-service-clusterip.s11.svc.cluster.local 2>&1 | tail -n 3; echo "--- but the ClusterIP still works:"; kubectl -n s11 exec curl-client -- curl -s -m 5 -o /dev/null -w "HTTP %{http_code} (by IP)\n" http://$(kubectl -n s11 get svc web-service-clusterip -o jsonpath="{.spec.clusterIP}"):8080; echo "--- restore:"; kubectl -n kube-system scale deploy coredns --replicas=1; kubectl -n kube-system rollout status deploy/coredns --timeout=90s
--- 3 scale CoreDNS to 0 -> DNS outage:
deployment.apps/coredns scaled

nslookup: write to '10.96.0.10': Connection refused
command terminated with exit code 1
--- but the ClusterIP still works:
HTTP 200 (by IP)
--- restore:
deployment.apps/coredns scaled
Waiting for deployment "coredns" rollout to finish: 0 of 1 updated replicas are available...
deployment "coredns" successfully rolled out

$ sleep 5; kubectl -n s11 exec curl-client -- nslookup web-service-clusterip.s11.svc.cluster.local | tail -n 3
Name:	web-service-clusterip.s11.svc.cluster.local
Address: 10.110.106.98
```
**Findings:** (1) a missing Service gives `NXDOMAIN`; (2) a Service whose selector matches no Pods has `ENDPOINTS <none>` – DNS resolves but the connection fails (exit 7); (3) with CoreDNS scaled to 0 all name lookups fail (`Connection refused` to 10.96.0.10) while direct ClusterIP access still works – proof that DNS, not networking, is the broken layer; scaling back to 1 replica restored resolution.
