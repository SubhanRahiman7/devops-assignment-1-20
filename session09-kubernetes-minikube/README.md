# Session 9 – Kubernetes Fundamentals (Minikube)

## 1. Install & configure Minikube
```bash
brew install minikube kubectl            # macOS (Docker Desktop must be running)
minikube start --driver=docker           # create a single-node local cluster
minikube status                          # verify
kubectl get nodes                        # verify the node is Ready
```
Minikube runs a one-node Kubernetes cluster inside a Docker container (driver `docker`), good for learning. Versions used: minikube v1.39.0, Kubernetes v1.37.0, kubectl v1.37.0.

## 2. Verify the cluster status
```text
$ minikube version
minikube version: v1.39.0
commit: 7a9f6a841470a207de8cf4bafcccee0969d8ba10

$ kubectl version
Client Version: v1.37.0
Kustomize Version: v5.8.1
Server Version: v1.37.0

$ minikube status
minikube
type: Control Plane
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured


$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:49938
CoreDNS is running at https://127.0.0.1:49938/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

$ kubectl get nodes -o wide
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION             CONTAINER-RUNTIME
minikube   Ready    control-plane   18d   v1.37.0   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   6.12.54-linuxkit (arm64)   containerd://2.3.4

$ kubectl get pods -n kube-system -o wide
NAME                               READY   STATUS    RESTARTS      AGE   IP             NODE       NOMINATED NODE   READINESS GATES
coredns-559f6c778d-x9kxq           1/1     Running   2 (99s ago)   18d   10.244.0.2     minikube   <none>           <none>
etcd-minikube                      1/1     Running   2 (99s ago)   18d   192.168.49.2   minikube   <none>           <none>
kindnet-l876n                      1/1     Running   2 (99s ago)   18d   192.168.49.2   minikube   <none>           <none>
kube-apiserver-minikube            1/1     Running   2 (99s ago)   18d   192.168.49.2   minikube   <none>           <none>
kube-controller-manager-minikube   1/1     Running   2 (99s ago)   18d   192.168.49.2   minikube   <none>           <none>
kube-proxy-nj2rn                   1/1     Running   2 (99s ago)   18d   192.168.49.2   minikube   <none>           <none>
kube-scheduler-minikube            1/1     Running   2 (99s ago)   18d   192.168.49.2   minikube   <none>           <none>
metrics-server-768f9f6999-z6ftw    1/1     Running   4 (63s ago)   18d   10.244.0.4     minikube   <none>           <none>
storage-provisioner                1/1     Running   4 (64s ago)   18d   192.168.49.2   minikube   <none>           <none>

$ kubectl get componentstatuses 2>&1 | head -5
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE   ERROR
scheduler            Healthy   ok        
controller-manager   Healthy   ok        
etcd-0               Healthy   ok        

$ kubectl get ns
NAME              STATUS   AGE
default           Active   18d
kube-node-lease   Active   18d
kube-public       Active   18d
kube-system       Active   18d

$ kubectl api-resources | head -n 20
NAME                                SHORTNAMES   APIVERSION                        NAMESPACED   KIND
bindings                                         v1                                true         Binding
componentstatuses                   cs           v1                                false        ComponentStatus
configmaps                          cm           v1                                true         ConfigMap
endpoints                           ep           v1                                true         Endpoints
events                              ev           v1                                true         Event
limitranges                         limits       v1                                true         LimitRange
namespaces                          ns           v1                                false        Namespace
nodes                               no           v1                                false        Node
persistentvolumeclaims              pvc          v1                                true         PersistentVolumeClaim
persistentvolumes                   pv           v1                                false        PersistentVolume
pods                                po           v1                                true         Pod
podtemplates                                     v1                                true         PodTemplate
replicationcontrollers              rc           v1                                true         ReplicationController
resourcequotas                      quota        v1                                true         ResourceQuota
secrets                                          v1                                true         Secret
serviceaccounts                     sa           v1                                true         ServiceAccount
services                            svc          v1                                true         Service
mutatingadmissionpolicies                        admissionregistration.k8s.io/v1   false        MutatingAdmissionPolicy
mutatingadmissionpolicybindings                  admissionregistration.k8s.io/v1   false        MutatingAdmissionPolicyBinding

$ minikube addons list | sed "s/\x1b\[[0-9;]*m//g" | head -n 12
┌─────────────────────────────┬──────────┬────────────┬────────────────────────────────────────┐
│         ADDON NAME          │ PROFILE  │   STATUS   │               MAINTAINER               │
├─────────────────────────────┼──────────┼────────────┼────────────────────────────────────────┤
│ ambassador                  │ minikube │ disabled   │ 3rd party (Ambassador)                 │
│ amd-gpu-device-plugin       │ minikube │ disabled   │ 3rd party (AMD)                        │
│ auto-pause                  │ minikube │ disabled   │ minikube                               │
│ cloud-spanner               │ minikube │ disabled   │ Google                                 │
│ csi-hostpath-driver         │ minikube │ disabled   │ Kubernetes                             │
│ dashboard                   │ minikube │ disabled   │ Kubernetes                             │
│ default-storageclass        │ minikube │ enabled ✅ │ Kubernetes                             │
│ efk                         │ minikube │ disabled   │ 3rd party (Elastic)                    │
│ freshpod                    │ minikube │ disabled   │ Google                                 │

$ kubectl config current-context; kubectl config get-contexts
minikube
CURRENT   NAME       CLUSTER    AUTHINFO   NAMESPACE
*         minikube   minikube   minikube   default

$ kubectl describe node minikube | sed -n "1,12p;/Capacity/,/Allocatable/p"
Name:               minikube
Roles:              control-plane
Labels:             beta.kubernetes.io/arch=arm64
                    beta.kubernetes.io/os=linux
                    kubernetes.io/arch=arm64
                    kubernetes.io/hostname=minikube
                    kubernetes.io/os=linux
                    minikube.k8s.io/commit=7a9f6a841470a207de8cf4bafcccee0969d8ba10
                    minikube.k8s.io/name=minikube
                    minikube.k8s.io/primary=true
                    minikube.k8s.io/updated_at=2026_09_19T12_57_30_0700
                    minikube.k8s.io/version=v1.39.0
Capacity:
  cpu:                11
  ephemeral-storage:  485442527232
  hugepages-1Gi:      0
  hugepages-2Mi:      0
  hugepages-32Mi:     0
  hugepages-64Ki:     0
  memory:             8024712Ki
  pods:               110
Allocatable:
```
**Result:** the node `minikube` is `Ready`, all control-plane pods (`etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`) and `coredns`, `kube-proxy`, `kindnet`, `storage-provisioner`, `metrics-server` are `Running`; scheduler/controller-manager/etcd report `Healthy`.

## 3. Kubernetes architecture – short notes

```
                 ┌──────────────────── Control Plane (master) ────────────────────┐
 kubectl ──────► │ kube-apiserver ◄──► etcd (cluster state)                       │
 (user/CI)       │      ▲        kube-scheduler  |  kube-controller-manager      │
                 └──────┼─────────────────────────────────────────────────────────┘
                        │ watches / instructions
        ┌───────────────┴──────────────── Worker Node ────────────────────────────┐
        │ kubelet  ── container runtime (containerd) ── Pods [container][container] │
        │ kube-proxy (Service networking)                                          │
        └───────────────────────────────────────────────────────────────────────────┘
```
| Component | Role |
|---|---|
| **kube-apiserver** | Front door of the cluster; every kubectl/controller call goes through this REST API (authN/authZ, validation). |
| **etcd** | Consistent key-value store holding the entire cluster state. |
| **kube-scheduler** | Chooses a node for each new Pod (resources, affinity, taints). |
| **kube-controller-manager** | Runs controllers (Deployment, ReplicaSet, Node, Endpoints…) that move *actual state → desired state*. |
| **cloud-controller-manager** | Talks to cloud provider APIs (LB, volumes) – not present in Minikube. |
| **kubelet** | Agent on each node; starts containers for Pods and reports health. |
| **kube-proxy** | Programs iptables/IPVS rules so Services route to Pods. |
| **Container runtime** | Runs containers (containerd here). |
| **CoreDNS** | Cluster DNS: `service.namespace.svc.cluster.local`. |

**Flow:** `kubectl apply` → API server stores it in etcd → controller creates ReplicaSet/Pods → scheduler assigns node → kubelet pulls image & starts the container → kube-proxy/Service exposes it. Kubernetes continuously **reconciles** desired vs actual state (self-healing).

## 4. Basic Kubernetes objects & commands
| Object | Purpose |
|---|---|
| Pod | Smallest deployable unit (1+ containers sharing network/storage) |
| ReplicaSet | Keeps N identical Pods running |
| Deployment | Manages ReplicaSets; rolling updates & rollback |
| Service | Stable IP/DNS + load balancing for Pods (ClusterIP/NodePort/LoadBalancer) |
| Namespace | Logical isolation inside a cluster |
| ConfigMap / Secret | Configuration / sensitive data |
| Ingress | HTTP(S) routing into the cluster |
| PV / PVC | Persistent storage |
| DaemonSet / StatefulSet / Job | Pod per node / stateful apps / run-to-completion |

```bash
kubectl get pods|svc|deploy|nodes|all [-n ns] [-o wide]
kubectl describe pod <name>        kubectl logs <pod>        kubectl exec -it <pod> -- sh
kubectl apply -f file.yaml         kubectl delete -f file.yaml
kubectl scale deploy <n> --replicas=3
kubectl set image deploy/<n> <container>=<image>
kubectl rollout status|history|undo deploy/<n>
kubectl expose deploy <n> --type=NodePort --port=80
```

## 5. Hands-on: Kubernetes Basics tutorial
Follows the official *Kubernetes Basics* tutorial (create Deployment → explore Pods → expose Service → scale → rolling update → rollback). The tutorial's sample image `kubernetes-bootcamp` is **amd64-only** and crashes on Apple-Silicon (`exec /bin/sh: exec format error`), so the same steps were performed with the multi-arch `nginx` images (`1.24-alpine` → `1.25-alpine`). All objects live in namespace `s9`.

```text
$ kubectl create namespace s9
namespace/s9 created

$ kubectl -n s9 create deployment web-basics --image=nginx:1.24-alpine --replicas=1
deployment.apps/web-basics created

$ kubectl -n s9 rollout status deployment/web-basics --timeout=180s
  ... (1 "Waiting for..." progress lines omitted)
deployment "web-basics" successfully rolled out

$ kubectl -n s9 get deployments; kubectl -n s9 get pods -o wide
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
web-basics   1/1     1            1           37s
NAME                          READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
web-basics-6c78dcd7fc-dd6tt   1/1     Running   0          37s   10.244.0.28   minikube   <none>           <none>

$ kubectl -n s9 expose deployment/web-basics --type=NodePort --port=80
service/web-basics exposed

$ kubectl -n s9 get services
NAME         TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
web-basics   NodePort   10.109.119.190   <none>        80:32299/TCP   0s

$ POD=$(kubectl -n s9 get pods -o jsonpath="{.items[0].metadata.name}"); kubectl -n s9 exec $POD -- wget -qO- localhost | head -n 5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>

$ kubectl -n s9 scale deployment/web-basics --replicas=4; kubectl -n s9 rollout status deployment/web-basics --timeout=120s; kubectl -n s9 get pods
deployment.apps/web-basics scaled
  ... (3 "Waiting for..." progress lines omitted)
deployment "web-basics" successfully rolled out
NAME                          READY   STATUS    RESTARTS   AGE
web-basics-6c78dcd7fc-8m7d9   1/1     Running   0          1s
web-basics-6c78dcd7fc-9l5p6   1/1     Running   0          1s
web-basics-6c78dcd7fc-dd6tt   1/1     Running   0          38s
web-basics-6c78dcd7fc-kwxss   1/1     Running   0          1s

$ kubectl -n s9 set image deployment/web-basics nginx=nginx:1.25-alpine; kubectl -n s9 rollout status deployment/web-basics --timeout=240s
deployment.apps/web-basics image updated
  ... (15 "Waiting for..." progress lines omitted)
deployment "web-basics" successfully rolled out

$ kubectl -n s9 get pods; kubectl -n s9 describe deployment web-basics | grep -i "image:"
NAME                          READY   STATUS    RESTARTS   AGE
web-basics-6dc896b544-cxpz2   1/1     Running   0          2s
web-basics-6dc896b544-p9chg   1/1     Running   0          10s
web-basics-6dc896b544-r9jx9   1/1     Running   0          10s
web-basics-6dc896b544-s5kr9   1/1     Running   0          1s
    Image:         nginx:1.25-alpine

$ kubectl -n s9 rollout undo deployment/web-basics; kubectl -n s9 rollout status deployment/web-basics --timeout=240s; kubectl -n s9 rollout history deployment/web-basics
deployment.apps/web-basics rolled back
  ... (13 "Waiting for..." progress lines omitted)
deployment "web-basics" successfully rolled out
deployment.apps/web-basics 
REVISION  CHANGE-CAUSE
2         <none>
3         <none>


$ kubectl -n s9 describe deployment web-basics | grep -i "image:"
    Image:         nginx:1.24-alpine

$ kubectl -n s9 logs deploy/web-basics --tail=3
Found 8 pods, using pod/web-basics-6dc896b544-p9chg
2026/10/07 16:53:35 [notice] 1#1: start worker process 38
2026/10/07 16:53:35 [notice] 1#1: start worker process 39
2026/10/07 16:53:35 [notice] 1#1: start worker process 40

$ kubectl -n s9 get all
NAME                              READY   STATUS        RESTARTS   AGE
pod/web-basics-6c78dcd7fc-gvk92   1/1     Running       0          1s
pod/web-basics-6c78dcd7fc-hbmg4   1/1     Running       0          1s
pod/web-basics-6c78dcd7fc-kjnkr   1/1     Running       0          1s
pod/web-basics-6c78dcd7fc-lhd2r   1/1     Running       0          1s
pod/web-basics-6dc896b544-cxpz2   0/1     Completed     0          3s
pod/web-basics-6dc896b544-p9chg   1/1     Terminating   0          11s
pod/web-basics-6dc896b544-r9jx9   0/1     Completed     0          11s
pod/web-basics-6dc896b544-s5kr9   0/1     Completed     0          2s

NAME                 TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/web-basics   NodePort   10.109.119.190   <none>        80:32299/TCP   12s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web-basics   4/4     4            4           49s

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/web-basics-6c78dcd7fc   4         4         4       49s
replicaset.apps/web-basics-6dc896b544   0         0         0       11s
```
**Observations:** Deployment → ReplicaSet → Pods; Service `NodePort 80:32299`; scale 1→4; image update created a **new ReplicaSet** (`6dc896b544`) while the old one scaled to 0 (rolling update); `rollout undo` brought the old ReplicaSet back (`REVISION 3`).
