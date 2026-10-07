# FQDN & Kubernetes DNS

## What is an FQDN?
A **Fully Qualified Domain Name** is the complete DNS name of a host, from the host label up to the root, with no ambiguity – e.g. `www.example.com.` (the trailing dot is the root). A *partial* name such as `www` depends on the resolver's **search domains** to be completed.

## Kubernetes Service DNS
Every Service gets a DNS record created by CoreDNS:

```
<service-name>.<namespace>.svc.<cluster-domain>
web-service-clusterip.s11.svc.cluster.local
```
| Part | Meaning |
|---|---|
| `web-service-clusterip` | Service name |
| `s11` | Namespace |
| `svc` | Fixed sub-domain for Services |
| `cluster.local` | Default cluster domain |

Other record types:
| Object | DNS name |
|---|---|
| Service | `my-svc.my-ns.svc.cluster.local` → ClusterIP |
| Headless Service | same name → **all Pod IPs** |
| StatefulSet Pod | `pod-0.my-svc.my-ns.svc.cluster.local` |
| Pod | `10-244-0-113.my-ns.pod.cluster.local` (IP with dashes) |
| SRV | `_http._tcp.my-svc.my-ns.svc.cluster.local` (port + name) |

## Namespace-based DNS / how short names work
Each Pod's `/etc/resolv.conf` contains search domains and `ndots:5`:
```
search s11.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10          # CoreDNS (kube-dns Service)
options ndots:5
```
A name with fewer than 5 dots is tried with each search domain appended. So **inside namespace `s11`**:
* `web-service-clusterip` → `…s11.svc.cluster.local` ✅ (same namespace)
* `other-app` (service in namespace `s11-other`) ❌ not found – the search path only covers the Pod's own namespace
* `other-app.s11-other` ✅ → resolved with `svc.cluster.local` appended
* Use the full FQDN (optionally with trailing dot) to skip the search list and avoid extra lookups.

## Pod-to-Service communication
The client Pod resolves the Service name through CoreDNS → gets the ClusterIP → kube-proxy DNATs the connection to one of the ready Pod IPs behind the Service.

## Examples of Kubernetes FQDNs
```
kubernetes.default.svc.cluster.local                 # API server Service
kube-dns.kube-system.svc.cluster.local               # CoreDNS
web-service-clusterip.s11.svc.cluster.local          # ClusterIP Service in s11
other-app.s11-other.svc.cluster.local                # Service in another namespace
web-stateful-0.web-service-headless.s11.svc.cluster.local   # StatefulSet Pod
10-244-0-113.s11.pod.cluster.local                   # Pod by IP
mysql.database.svc.cluster.local                     # typical DB service
```

## Hands-on proof (executed on Minikube)
```text
$ kubectl -n s11 exec curl-client -- cat /etc/resolv.conf
search s11.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5

$ kubectl -n s11 exec curl-client -- getent hosts web-service-clusterip
10.110.106.98     web-service-clusterip.s11.svc.cluster.local  web-service-clusterip.s11.svc.cluster.local web-service-clusterip

$ kubectl -n s11 exec curl-client -- getent hosts web-service-clusterip.s11
10.110.106.98     web-service-clusterip.s11.svc.cluster.local  web-service-clusterip.s11.svc.cluster.local web-service-clusterip.s11

$ kubectl -n s11 exec curl-client -- getent hosts web-service-clusterip.s11.svc.cluster.local
10.110.106.98     web-service-clusterip.s11.svc.cluster.local  web-service-clusterip.s11.svc.cluster.local

$ kubectl -n s11 exec curl-client -- nslookup web-service-clusterip.s11.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-service-clusterip.s11.svc.cluster.local
Address: 10.110.106.98



$ echo "--- different namespace: short name fails, namespace-qualified works"; kubectl -n s11 exec curl-client -- getent hosts other-app || echo "other-app (short name) -> NOT FOUND"; kubectl -n s11 exec curl-client -- getent hosts other-app.s11-other
--- different namespace: short name fails, namespace-qualified works
command terminated with exit code 2
other-app (short name) -> NOT FOUND
10.101.81.65      other-app.s11-other.svc.cluster.local  other-app.s11-other.svc.cluster.local other-app.s11-other

$ kubectl -n s11 exec curl-client -- curl -s -o /dev/null -w "HTTP %{http_code} from other-app.s11-other.svc.cluster.local\n" http://other-app.s11-other.svc.cluster.local
HTTP 200 from other-app.s11-other.svc.cluster.local

$ kubectl -n s11 get pods -l app=web-clusterip -o wide | head -n 2; POD_IP=$(kubectl -n s11 get pod -l app=web-clusterip -o jsonpath="{.items[0].status.podIP}"); echo "Pod DNS name: ${POD_IP//./-}.s11.pod.cluster.local"; kubectl -n s11 exec curl-client -- getent hosts ${POD_IP//./-}.s11.pod.cluster.local
NAME                                 READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
web-app-clusterip-66865d4855-h8sxv   1/1     Running   0          53s   10.244.0.113   minikube   <none>           <none>
Pod DNS name: 10-244-0-113.s11.pod.cluster.local
10.244.0.113      10-244-0-113.s11.pod.cluster.local  10-244-0-113.s11.pod.cluster.local

$ kubectl -n s11 exec curl-client -- nslookup -type=SRV _http._tcp.web-service-clusterip.s11.svc.cluster.local
Server:		10.96.0.10
Address:	10.96.0.10:53

_http._tcp.web-service-clusterip.s11.svc.cluster.local	service = 0 100 8080 web-service-clusterip.s11.svc.cluster.local


$ kubectl -n s11 exec curl-client -- nslookup -type=PTR $(kubectl -n s11 get svc web-service-clusterip -o jsonpath="{.spec.clusterIP}" | awk -F. "{print \$4\".\"\$3\".\"\$2\".\"\$1}").in-addr.arpa
Server:		10.96.0.10
Address:	10.96.0.10:53

98.106.110.10.in-addr.arpa	name = web-service-clusterip.s11.svc.cluster.local
```
**Observations:** the short name, `name.namespace` and full FQDN all return the same ClusterIP when called from the same namespace; the short name of a Service in *another* namespace is not found, but `other-app.s11-other` works; Pod, SRV and PTR (reverse) records exist too.
