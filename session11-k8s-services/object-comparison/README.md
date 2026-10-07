# Kubernetes Object Comparison (Task 2)

## 1. Deployment vs ReplicaSet

| | **ReplicaSet** | **Deployment** |
|---|---|---|
| **Purpose** | Ensure a fixed number of identical Pods is always running | Declarative management of an application's Pods **and its versions** |
| **Pod management** | Creates/replaces Pods from a template to match `replicas`; selects Pods by label | Creates and owns ReplicaSets; the ReplicaSets create the Pods |
| **Scaling** | `kubectl scale rs <n> --replicas=N` (manual) | `kubectl scale deploy <n> --replicas=N` (passes it to the ReplicaSet); works with HPA |
| **Rolling updates** | ❌ Not supported – changing the Pod template does **not** update existing Pods | ✅ Built in (`RollingUpdate`, `Recreate`), `maxSurge` / `maxUnavailable` |
| **Rollback / history** | ❌ | ✅ `kubectl rollout undo / history` (old ReplicaSets are kept with 0 replicas) |
| **Use directly?** | Rarely | Yes – the standard way to run stateless apps |

**Relationship:** `Deployment → ReplicaSet → Pods`. On an image change the Deployment creates a **new** ReplicaSet, scales it up while scaling the old one down (that is the rolling update). Seen in Session 10: `app-rolling-86d7…` (v1, 4→0) and `app-rolling-56bf…` (v2, 0→4) were two ReplicaSets of the same Deployment.

```text
Deployment  app-rolling
 ├── ReplicaSet app-rolling-86d7d44d5b   DESIRED 0   (v1, kept for rollback)
 └── ReplicaSet app-rolling-56bff6d88c   DESIRED 4   (v2, active)
        └── 4 Pods
```

## 2. Deployment vs DaemonSet vs StatefulSet

| | **Deployment** | **DaemonSet** | **StatefulSet** |
|---|---|---|---|
| **Use case** | Stateless apps (web, APIs, microservices) | One Pod **on every (selected) node** – node-level agents | Stateful apps needing identity & storage – databases, Kafka, Zookeeper, Elasticsearch |
| **Pod creation** | Random names (`web-6c78…-x2k`), created in parallel, interchangeable | One Pod per node, created automatically when a node joins (name `agent-abcde`) | Ordered, stable names `db-0, db-1, db-2`; created/deleted **in order** (0→N), one at a time by default |
| **Scaling** | `replicas: N` / HPA | No replica count – scales with the **number of nodes** (use `nodeSelector`/tolerations to limit) | `replicas: N`; scale up adds highest ordinal, scale down removes highest first |
| **Networking** | Usually a normal ClusterIP Service in front; Pods are anonymous | Often `hostNetwork`/`hostPort`, accessed locally per node | **Headless Service** gives each Pod a stable DNS name `db-0.db-svc.ns.svc.cluster.local` |
| **Storage** | Shared or ephemeral volumes; PVC is shared by all replicas | Usually hostPath (logs, `/var/lib`) | `volumeClaimTemplates` → **its own PVC per Pod** that sticks to the Pod identity across restarts |
| **Update strategy** | RollingUpdate / Recreate | RollingUpdate / OnDelete | RollingUpdate (reverse ordinal) with `partition`, or OnDelete |
| **Examples** | nginx, Node/Python API, React frontend | Fluent Bit/Filebeat (logs), node-exporter (metrics), kube-proxy, CNI plugins | MySQL/PostgreSQL cluster, MongoDB, Redis cluster, Kafka |

Hands-on evidence: the headless Service demo (Session 11, `05-headless`) created StatefulSet Pods `web-stateful-0/1/2` with per-Pod DNS names; Session 10 `daemonset/node-agent-ds.yaml` runs one Pod per node.

```yaml
# DaemonSet – no replicas field
kind: DaemonSet
spec:
  selector: { matchLabels: { app: node-agent } }
---
# StatefulSet – stable identity + own volume per Pod
kind: StatefulSet
spec:
  serviceName: db-headless
  replicas: 3
  volumeClaimTemplates:
    - metadata: { name: data }
      spec: { accessModes: [ReadWriteOnce], resources: { requests: { storage: 1Gi } } }
```

## 3. ReplicaSet vs Service

| | **ReplicaSet** | **Service** |
|---|---|---|
| **Responsibility** | Keep the desired **number** of Pods running (self-healing, availability) | Give a group of Pods a **stable network identity** (virtual IP + DNS name) and load-balance traffic |
| Works on | Pod lifecycle (create/delete) | Network access to Pods |
| Selects Pods with | label selector (to count and own Pods) | label selector (to build the list of **endpoints**) |
| Knows about traffic? | No | Yes |

**Why a Service is required:** Pod IPs are **ephemeral** – when a Pod dies the ReplicaSet creates a new one with a **different IP**, and during scaling/rolling updates the set of Pods keeps changing. Clients cannot track that. A Service provides a fixed ClusterIP/DNS name and only routes to *Ready* Pods.

**How traffic reaches Pods:**
```text
Client ─► web-service (DNS: web-service.ns.svc.cluster.local → ClusterIP)
           │  kube-proxy (iptables/IPVS) on each node
           ▼  picks one ready endpoint (EndpointSlice built from the label selector)
        Pod-1 ─ Pod-2 ─ Pod-3     ◄── created/replaced by the ReplicaSet
```
1. The Service's selector (`app=web`) is matched against Pod labels → ready Pod IPs become the endpoints.
2. The client resolves the Service name through CoreDNS and connects to the ClusterIP.
3. kube-proxy rewrites (DNAT) the destination to one endpoint.
4. If the ReplicaSet replaces a Pod, the endpoint list updates automatically – the client keeps using the same Service name.

Seen in practice: Session 11 `ghost` Service with no matching Pods had `ENDPOINTS <none>` – the name resolved but nothing answered, and in Session 10 blue-green the traffic switch was just changing the Service **selector** while ReplicaSets/Pods stayed untouched.
