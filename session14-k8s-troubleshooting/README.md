# Session 14 – Kubernetes Troubleshooting

> **Troubleshooting mindset:** Observe → identify the resource → check **status** (`get`) → check **details** (`describe`) → check **events** → check **logs** → get inside (`exec`) → test connectivity → find the **root cause** → fix → verify.

All exercises ran on Minikube (arm64) in dedicated namespaces (`s14`, `s14m`). Manifests: [`01-commands/`](01-commands/), [`02-issues/`](02-issues/), [`mini-project/`](mini-project/).

| # | Section |
|---|---|
| Task 1 | [kubectl commands](#task-1--kubectl-troubleshooting-commands) |
| Task 2 | [Common issues](#task-2--troubleshoot-common-issues): CrashLoopBackOff, ImagePullBackOff/ErrImagePull, Pending, ContainerCreating, Service connectivity, DNS, Pod networking, Configuration (+ OOMKilled) |
| Task 3 | [Mini project](#task-3--mini-project) |

---
# Task 1 – kubectl troubleshooting commands
```text
$ kubectl -n s14 apply -f 01-commands/get-demo.yaml -f 01-commands/logs-demo.yaml -f 01-commands/exec-demo.yaml; kubectl -n s14 wait --for=condition=Ready pod --all 
pod/get-demo created
pod/logs-demo created
pod/exec-demo created
pod/exec-demo condition met
pod/get-demo condition met
pod/logs-demo condition met
```

## `kubectl get` – *what exists and what is its status?*
Lists resources. Useful options: `-o wide` (node, IP), `-o yaml/json/jsonpath/custom-columns`, `--show-labels`, `-l key=value`, `-A`, `-w` (watch).
```text
$ kubectl -n s14 get pods
NAME        READY   STATUS    RESTARTS   AGE
exec-demo   1/1     Running   0          1s
get-demo    1/1     Running   0          1s
logs-demo   1/1     Running   0          1s

$ kubectl -n s14 get pods -o wide
NAME        READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
exec-demo   1/1     Running   0          1s    10.244.0.161   minikube   <none>           <none>
get-demo    1/1     Running   0          1s    10.244.0.159   minikube   <none>           <none>
logs-demo   1/1     Running   0          1s    10.244.0.160   minikube   <none>           <none>

$ kubectl -n s14 get pods --show-labels; kubectl -n s14 get pods -l app=get-demo
NAME        READY   STATUS    RESTARTS   AGE   LABELS
exec-demo   1/1     Running   0          1s    <none>
get-demo    1/1     Running   0          1s    app=get-demo
logs-demo   1/1     Running   0          1s    <none>
NAME       READY   STATUS    RESTARTS   AGE
get-demo   1/1     Running   0          1s

$ kubectl -n s14 get pod get-demo -o yaml | head -n 30
apiVersion: v1
kind: Pod
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Pod","metadata":{"annotations":{},"labels":{"app":"get-demo"},"name":"get-demo","namespace":"s14"},"spec":{"containers":[{"image":"n
  creationTimestamp: "2026-10-07T18:06:09Z"
  generation: 1
  labels:
    app: get-demo
  name: get-demo
  namespace: s14
  resourceVersion: "36725"
  uid: 87d38da1-75f9-42ea-8907-5f2a5225a91e
spec:
  containers:
  - image: nginx:1.27
    imagePullPolicy: IfNotPresent
    name: nginx
    ports:
    - containerPort: 80
      protocol: TCP
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: kube-api-access-4g4mp
      readOnly: true
  dnsPolicy: ClusterFirst

$ kubectl -n s14 get pod get-demo -o jsonpath="{.status.podIP} {.status.phase} {.spec.nodeName}{\"\n\"}"; kubectl -n s14 get pods -o custom-columns=NAME:.metadata.na
10.244.0.159 Running minikube
NAME        STATUS    IP
exec-demo   Running   10.244.0.161
get-demo    Running   10.244.0.159
logs-demo   Running   10.244.0.160

$ kubectl -n s14 get all; kubectl get nodes -o wide; kubectl get ns
NAME            READY   STATUS    RESTARTS   AGE
pod/exec-demo   1/1     Running   0          1s
pod/get-demo    1/1     Running   0          1s
pod/logs-demo   1/1     Running   0          1s
NAME       STATUS   ROLES           AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION             CONTAINER-RUNTIME
minikube   Ready    control-plane   18d   v1.37.0   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   6.12.54-linuxkit (arm64)   containerd://2.3.4
NAME                STATUS   AGE
default             Active   18d
ingress-nginx       Active   34m
kube-node-lease     Active   18d
kube-public         Active   18d
kube-system         Active   18d
production-webapp   Active   44s
s13                 Active   18m
s13-hpa             Active   18m
s14                 Active   1s
```
## `kubectl describe` – *why is it in this state?*
Shows configuration **and the Events** (scheduling, image pull, probe failures, mount errors…). First tool when `get` shows something wrong.
```text
$ kubectl -n s14 describe pod get-demo
Name:             get-demo
Namespace:        s14
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Start Time:       Wed, 07 Oct 2026 23:36:09 +0530
Labels:           app=get-demo
Annotations:      <none>
Status:           Running
IP:               10.244.0.159
IPs:
  IP:  10.244.0.159
Containers:
  nginx:
    Container ID:   containerd://efccc7403687e6499533e4ff1988c28fed8879bddb78dc54b28d77e667766764
    Image:          nginx:1.27
    Image ID:       docker.io/library/nginx@sha256:6784fb0834aa7dbbe12e3d7471e69c290df3e6ba810dc38b34ae33d3c1c05f7d
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Wed, 07 Oct 2026 23:36:09 +0530
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-4g4mp (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       True 
  ContainersReady             True 
  PodScheduled                True 
Volumes:
  kube-api-access-4g4mp:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   BestEffort
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  1s    default-scheduler  Successfully assigned s14/get-demo to minikube
  Normal  Pulled     1s    kubelet            spec.containers{nginx}: Container image "nginx:1.27" already present on machine and can be accessed by the pod
  Normal  Created    1s    kubelet            spec.containers{nginx}: Container created
  Normal  Started    1s    kubelet            spec.containers{nginx}: Container started
```
## `kubectl logs` – *what does the application say?*
`--tail`, `--since`, `-f` (follow), `-c <container>`, `--previous` (logs of the crashed container).
```text
$ kubectl -n s14 logs logs-demo
Application started
Connecting to database...
Database connection successful
Application is running
Application is healthy

$ kubectl -n s14 logs logs-demo --tail=2; kubectl -n s14 logs logs-demo --since=10s | head -n 3
Application is running
Application is healthy
Application started
Connecting to database...
Database connection successful
```
## `kubectl exec` – *look/test from inside the container*
Run commands (`curl`, `env`, `ls`, `nslookup`) or open a shell with `kubectl exec -it <pod> -- sh`.
```text
$ kubectl -n s14 exec exec-demo -- nginx -v; kubectl -n s14 exec exec-demo -- cat /etc/os-release | head -n 2; kubectl -n s14 exec exec-demo -- sh -c "ls /usr/share/
nginx version: nginx/1.27.5
PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"
NAME="Debian GNU/Linux"
50x.html
index.html
curl localhost -> HTTP 200

$ echo "(interactive form: kubectl exec -it exec-demo -- bash)"; kubectl -n s14 exec exec-demo -- sh -c "hostname; ps aux | head -n 3; env | grep -E \"^(HOSTNAME|NGI
(interactive form: kubectl exec -it exec-demo -- bash)
exec-demo
sh: 1: ps: not found
HOSTNAME=exec-demo
NGINX_VERSION=1.27.5
```
## Events – `kubectl get events` / `kubectl events`
Cluster-level timeline (Scheduled, Pulled, Created, Started, Failed, BackOff…).
```text
$ kubectl -n s14 get events --sort-by=.metadata.creationTimestamp | tail -n 12
1s          Normal   Scheduled   pod/exec-demo   Successfully assigned s14/exec-demo to minikube
1s          Normal   Pulled      pod/exec-demo   Container image "nginx:1.27" already present on machine and can be accessed by the pod
1s          Normal   Created     pod/exec-demo   Container created
1s          Normal   Started     pod/exec-demo   Container started
1s          Normal   Scheduled   pod/get-demo    Successfully assigned s14/get-demo to minikube
1s          Normal   Pulled      pod/get-demo    Container image "nginx:1.27" already present on machine and can be accessed by the pod
1s          Normal   Created     pod/get-demo    Container created
1s          Normal   Started     pod/get-demo    Container started
1s          Normal   Scheduled   pod/logs-demo   Successfully assigned s14/logs-demo to minikube
1s          Normal   Pulled      pod/logs-demo   Container image "busybox:1.36" already present on machine and can be accessed by the pod
1s          Normal   Created     pod/logs-demo   Container created
1s          Normal   Started     pod/logs-demo   Container started

$ kubectl -n s14 events --for pod/get-demo
LAST SEEN   TYPE     REASON      OBJECT         MESSAGE
1s          Normal   Pulled      Pod/get-demo   Container image "nginx:1.27" already present on machine and can be accessed by the pod
1s          Normal   Created     Pod/get-demo   Container created
1s          Normal   Started     Pod/get-demo   Container started
1s          Normal   Scheduled   Pod/get-demo   Successfully assigned s14/get-demo to minikube
```
## `kubectl explain` – *built-in API documentation*
```text
$ kubectl explain pod | head -n 12; kubectl explain pod.spec.containers.resources
KIND:       Pod
VERSION:    v1

DESCRIPTION:
    Pod is a collection of containers that can run on a host. This resource is
    created by clients and scheduled onto hosts.
    
FIELDS:
  apiVersion	<string>
    APIVersion defines the versioned schema of this representation of an object.
    Servers should convert recognized schemas to the latest internal value, and
    may reject unrecognized values. More info:
KIND:       Pod
VERSION:    v1

FIELD: resources <ResourceRequirements>


DESCRIPTION:
    Compute Resources required by this container. Cannot be updated. More info:
    https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
    ResourceRequirements describes the compute resource requirements.
    
FIELDS:
  claims	<[]ResourceClaim>
    Claims lists the names of resources, defined in spec.resourceClaims, that
    are used by this container.
    
    This field depends on the DynamicResourceAllocation feature gate.
    
    This field is immutable. It can only be set for containers.

  limits	<map[string]Quantity>
    Limits describes the maximum amount of compute resources allowed. More info:
    https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/

  requests	<map[string]Quantity>
    Requests describes the minimum amount of compute resources required. If
    Requests is omitted for a container, it defaults to Limits if that is
    explicitly specified, otherwise to an implementation-defined value. Requests
    cannot exceed Limits. More info:
    https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/



$ kubectl explain deployment.spec.strategy.rollingUpdate
GROUP:      apps
KIND:       Deployment
VERSION:    v1

FIELD: rollingUpdate <RollingUpdateDeployment>


DESCRIPTION:
    Rolling update config params. Present only if DeploymentStrategyType =
    RollingUpdate.
    Spec to control the desired behavior of rolling update.
    
FIELDS:
  maxSurge	<IntOrString>
    The maximum number of pods that can be scheduled above the desired number of
    pods. Value can be an absolute number (ex: 5) or a percentage of desired
    pods (ex: 10%). This can not be 0 if MaxUnavailable is 0. Absolute number is
    calculated from percentage by rounding up. Defaults to 25%. Example: when
    this is set to 30%, the new ReplicaSet can be scaled up immediately when the
    rolling update starts, such that the total number of old and new pods do not
    exceed 130% of desired pods. Once old pods have been killed, new ReplicaSet
    can be scaled up further, ensuring that total number of pods running at any
    time during the update is at most 130% of desired pods.

  maxUnavailable	<IntOrString>
    The maximum number of pods that can be unavailable during the update. Value
    can be an absolute number (ex: 5) or a percentage of desired pods (ex: 10%).
    Absolute number is calculated from percentage by rounding down. This can not
    be 0 if MaxSurge is 0. Defaults to 25%. Example: when this is set to 30%,
    the old ReplicaSet can be scaled down to 70% of desired pods immediately
    when the rolling update starts. Once new pods are ready, old ReplicaSet can
    be scaled down further, followed by scaling up the new ReplicaSet, ensuring
    that the total number of pods available at all times during the update is at
    least 70% of desired pods.
```
## `kubectl top` – *resource usage (needs metrics-server)*
```text
$ kubectl top nodes; kubectl -n s14 top pods; kubectl -n s14 top pods --containers
NAME       CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
minikube   213m         1%       1991Mi          25%         
error: metrics not available yet
error: metrics not available yet
```
| Command | Answers |
|---|---|
| `get` | Is it running? Ready? Restarts? Which node/IP? |
| `describe` | Why not? (events, probes, mounts, scheduling) |
| `logs` | What did the app print / why did it crash? |
| `exec` | What does it look like inside; can it reach X? |
| `events` | What happened and when? |
| `explain` | Which fields exist in this YAML? |
| `top` | CPU / memory pressure? |

---
# Task 2 – Troubleshoot common issues
Each issue follows: **Identify → Investigate → Root cause → Fix → Verify.**

## 1. CrashLoopBackOff
| | |
|---|---|
| Identify | `kubectl get pod` → `Error`, `RESTARTS` increasing (the docs call the waiting state *CrashLoopBackOff*; this Minikube build shows `Error` between restarts; the `BackOff` event confirms it) |
| Investigate | `describe` (Exit Code 1, `Back-off restarting failed container`), `logs`, `logs --previous` |
| Root cause | The container's command ends with `exit 1` ("Something went wrong!") – the process exits, kubelet restarts it with growing delays |
| Fix | Fix the application/command so the process keeps running (recreate the Pod: `fixed.yaml`) |
| Verify | Pod `1/1 Running`, restarts 0 |
```text
$ kubectl -n s14 apply -f 02-issues/crashloopbackoff/broken.yaml; sleep 45; kubectl -n s14 get pod crash-demo
pod/crash-demo created
NAME         READY   STATUS   RESTARTS      AGE
crash-demo   0/1     Error    3 (30s ago)   45s

$ kubectl -n s14 describe pod crash-demo | grep -E "State|Reason|Exit Code|Restart Count|BackOff"; kubectl -n s14 logs crash-demo; kubectl -n s14 logs crash-demo --p
    State:          Terminated
      Reason:       Error
      Exit Code:    1
    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
    Restart Count:  3
  Type     Reason     Age               From               Message
  Warning  BackOff    8s (x3 over 43s)  kubelet            spec.containers{app}: Back-off restarting failed container app in pod crash-demo_s14(7368c421-5774-4fc5-82
Application starting...
Something went wrong!
unable to retrieve container logs for containerd://e7397f7e4dfb7a4e283e959d899b56f7b8d77537156bec4c26ffd6d7c70ca586
$ echo "--- FIX: container must keep running (pod spec command cannot be edited in place -> recreate)"; kubectl -n s14 delete pod crash-demo --wait=true; kubectl -n 
--- FIX: container must keep running (pod spec command cannot be edited in place -> recreate)
pod "crash-demo" deleted from s14 namespace
pod/crash-demo created
pod/crash-demo condition met
NAME         READY   STATUS    RESTARTS   AGE
crash-demo   1/1     Running   0          1s
Application starting...
Application is healthy
```

## 2. ImagePullBackOff / ErrImagePull
| | |
|---|---|
| Identify | `ErrImagePull` first, then `ImagePullBackOff` |
| Investigate | `describe pod` / `events` → `Failed to pull image "nginx:this-image-does-not-exist": … NotFound` |
| Root cause | The image tag does not exist (typo / wrong tag / private registry without `imagePullSecrets`) |
| Fix | Use a valid image tag (`nginx:1.27`) |
| Verify | `1/1 Running` |
```text
$ kubectl -n s14 apply -f 02-issues/imagepullbackoff/broken.yaml; sleep 25; kubectl -n s14 get pod image-demo
pod/image-demo created
NAME         READY   STATUS             RESTARTS   AGE
image-demo   0/1     ImagePullBackOff   0          25s

$ kubectl -n s14 describe pod image-demo | grep -E "Reason|Failed|BackOff|image" | cut -c1-200
Name:             image-demo
    Image:          nginx:this-image-does-not-exist
      Reason:       ImagePullBackOff
  Type     Reason     Age               From               Message
  Normal   Scheduled  25s               default-scheduler  Successfully assigned s14/image-demo to minikube
  Normal   BackOff    20s               kubelet            spec.containers{app}: Back-off pulling image "nginx:this-image-does-not-exist"
  Warning  Failed     20s               kubelet            spec.containers{app}: Error: ImagePullBackOff
  Normal   Pulling    9s (x2 over 25s)  kubelet            spec.containers{app}: Pulling image "nginx:this-image-does-not-exist"
  Warning  Failed     7s (x2 over 20s)  kubelet            spec.containers{app}: Failed to pull image "nginx:this-image-does-not-exist": rpc error: code = NotFound d
  Warning  Failed     7s (x2 over 20s)  kubelet            spec.containers{app}: Error: ErrImagePull

$ kubectl -n s14 events --for pod/image-demo | cut -c1-200
LAST SEEN          TYPE      REASON      OBJECT           MESSAGE
25s                Normal    Scheduled   Pod/image-demo   Successfully assigned s14/image-demo to minikube
20s                Normal    BackOff     Pod/image-demo   Back-off pulling image "nginx:this-image-does-not-exist"
20s                Warning   Failed      Pod/image-demo   Error: ImagePullBackOff
9s (x2 over 25s)   Normal    Pulling     Pod/image-demo   Pulling image "nginx:this-image-does-not-exist"
7s (x2 over 20s)   Warning   Failed      Pod/image-demo   Failed to pull image "nginx:this-image-does-not-exist": rpc error: code = NotFound desc = failed to pull an
7s (x2 over 20s)   Warning   Failed      Pod/image-demo   Error: ErrImagePull

$ echo "--- FIX: correct image tag"; kubectl -n s14 delete pod image-demo --wait=true; kubectl -n s14 apply -f 02-issues/imagepullbackoff/fixed.yaml; kubectl -n s14 
--- FIX: correct image tag
pod "image-demo" deleted from s14 namespace
pod/image-demo created
pod/image-demo condition met
NAME         READY   STATUS    RESTARTS   AGE
image-demo   1/1     Running   0          1s
```
*(`ErrImagePull` = the pull attempt failed right now; `ImagePullBackOff` = kubelet is waiting before retrying.)*

## 3. Pending
| | |
|---|---|
| Identify | `STATUS Pending`, no node assigned |
| Investigate | `describe` → `FailedScheduling: 0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector` |
| Root cause | `nodeSelector: kubernetes.io/hostname=node-that-does-not-exist` – no node has that label (other causes: insufficient CPU/memory – see Session 10 `lifecycle-pending`, taints, unbound PVC) |
| Fix | Remove/correct the selector |
| Verify | Pod scheduled to `minikube`, `Running` |
```text
$ kubectl -n s14 apply -f 02-issues/pending/broken.yaml; sleep 5; kubectl -n s14 get pod pending-demo
pod/pending-demo created
NAME           READY   STATUS    RESTARTS   AGE
pending-demo   0/1     Pending   0          5s

$ kubectl -n s14 describe pod pending-demo | grep -E "Node-Selectors|Status:|FailedScheduling" | cut -c1-200
Status:           Pending
Node-Selectors:              kubernetes.io/hostname=node-that-does-not-exist
  Warning  FailedScheduling  5s    default-scheduler  0/1 nodes are available: 1 node(s) didn't match Pod's node affinity/selector. preemption: 0/1 nodes are availab

$ kubectl get nodes --show-labels | tr "," "\n" | grep hostname
kubernetes.io/hostname=minikube

$ echo "--- FIX: remove the impossible nodeSelector"; kubectl -n s14 delete pod pending-demo --wait=true; kubectl -n s14 apply -f 02-issues/pending/fixed.yaml; kubec
--- FIX: remove the impossible nodeSelector
pod "pending-demo" deleted from s14 namespace
pod/pending-demo created
pod/pending-demo condition met
NAME           READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
pending-demo   1/1     Running   0          1s    10.244.0.172   minikube   <none>           <none>
```

## 4. ContainerCreating (stuck)
| | |
|---|---|
| Identify | `ContainerCreating` for more than a few seconds |
| Investigate | `describe` → `FailedMount: MountVolume.SetUp failed for volume "cfg" : configmap "missing-config" not found` |
| Root cause | The Pod mounts a ConfigMap that does not exist (other causes: image still pulling, missing Secret/PVC, CNI problem) |
| Fix | Create the ConfigMap – the kubelet retries automatically |
| Verify | Pod becomes `Running`, file visible in the container |
```text
$ kubectl -n s14 apply -f 02-issues/containercreating/broken.yaml; sleep 8; kubectl -n s14 get pod creating-demo
pod/creating-demo created
NAME            READY   STATUS              RESTARTS   AGE
creating-demo   0/1     ContainerCreating   0          8s

$ kubectl -n s14 describe pod creating-demo | grep -E "Status:|FailedMount|configmap" | cut -c1-200
Status:           Pending
  Warning  FailedMount  1s (x5 over 8s)  kubelet            MountVolume.SetUp failed for volume "cfg" : configmap "missing-config" not found

$ echo "--- FIX: create the missing ConfigMap"; kubectl -n s14 apply -f 02-issues/containercreating/fix-configmap.yaml; kubectl -n s14 wait --for=condition=Ready pod
--- FIX: create the missing ConfigMap
configmap/missing-config created
pod/creating-demo condition met
NAME            READY   STATUS    RESTARTS   AGE
creating-demo   1/1     Running   0          16s
mode=production
```

## 5. Service connectivity issues
Two bugs were tested: **(a)** wrong selector, **(b)** wrong `targetPort`.
| | (a) selector | (b) targetPort |
|---|---|---|
| Identify | `curl http://web-service` fails (exit 7) | same |
| Investigate | `get endpoints web-service` → `<none>`; `describe svc` Selector `app=web-ahsgdf` vs Pod label `app=web` | Endpoints exist but are `:8080`; `describe svc` TargetPort `8080` while nginx listens on 80 |
| Root cause | Selector does not match Pod labels → no endpoints | Traffic forwarded to a port nothing listens on |
| Fix | selector `app: web` | `targetPort: 80` |
| Verify | endpoints `IP:80`, HTTP 200 | HTTP 200 |
```text
$ kubectl -n s14 apply -f 02-issues/service-connectivity/deployment.yaml -f 02-issues/service-connectivity/broken-service.yaml; kubectl -n s14 rollout status deploy/
deployment.apps/web created
service/web-service created
deployment "web" successfully rolled out
pod/dns-client created
pod/dns-client condition met

$ kubectl -n s14 exec dns-client -- curl -s -m 4 -o /dev/null -w "HTTP %{http_code}\n" http://web-service || echo "-> connection FAILED"
HTTP 000
command terminated with exit code 7
-> connection FAILED

$ kubectl -n s14 get svc web-service; kubectl -n s14 get endpoints web-service
NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
web-service   ClusterIP   10.102.110.113   <none>        80/TCP    1s
NAME          ENDPOINTS   AGE
web-service   <none>      2s

$ kubectl -n s14 describe svc web-service | grep -E "Selector|Endpoints|TargetPort"; kubectl -n s14 get pods --show-labels | grep web-
Selector:                 app=web-ahsgdf
TargetPort:               80/TCP
Endpoints:                
web-557577df75-7p7sf   1/1     Running   0          2s      app=web,pod-template-hash=557577df75
web-557577df75-hxn26   1/1     Running   0          2s      app=web,pod-template-hash=557577df75

$ echo "--- FIX 1: selector must match the Pod label (app: web)"; kubectl -n s14 apply -f 02-issues/service-connectivity/fixed-service.yaml; sleep 3; kubectl -n s14 
--- FIX 1: selector must match the Pod label (app: web)
service/web-service configured
NAME          ENDPOINTS                         AGE
web-service   10.244.0.192:80,10.244.0.193:80   5s
HTTP 200

$ echo "--- Second bug: wrong targetPort"; kubectl -n s14 apply -f 02-issues/service-connectivity/wrong-targetport-service.yaml; sleep 3; kubectl -n s14 get endpoint
--- Second bug: wrong targetPort
service/web-service configured
NAME          ENDPOINTS                             AGE
web-service   10.244.0.192:8080,10.244.0.193:8080   8s
HTTP 000
command terminated with exit code 7
-> FAILED: endpoints exist but nothing listens on 8080

$ kubectl -n s14 describe svc web-service | grep -E "Port|TargetPort|Endpoints"; kubectl -n s14 exec web-$(kubectl -n s14 get pods -l app=web -o jsonpath="{.items[0]
Port:                     <unset>  80/TCP
TargetPort:               8080/TCP
Endpoints:                10.244.0.193:8080,10.244.0.192:8080
sh: 1: netstat: not found
command terminated with exit code 127

$ echo "--- FIX 2: targetPort 80"; kubectl -n s14 apply -f 02-issues/service-connectivity/fixed-service.yaml; sleep 3; kubectl -n s14 get endpoints web-service; kube
--- FIX 2: targetPort 80
service/web-service configured
NAME          ENDPOINTS                         AGE
web-service   10.244.0.192:80,10.244.0.193:80   11s
HTTP 200
```
*(The `netstat: not found` line is only my optional check – the minimal nginx image has no `netstat`; the connection failure and endpoint list already prove the cause.)*

## 6. DNS issues
| Symptom | Investigation | Root cause | Fix |
|---|---|---|---|
| `NXDOMAIN` | `nslookup web-servce…` | typo in the name | use the correct name |
| short name of a Service in another namespace fails | `/etc/resolv.conf` search path only has the Pod's namespace | namespace not in the name | use `service.namespace` |
| nothing resolves, but ClusterIP works | CoreDNS scaled to 0 | cluster DNS down | scale CoreDNS back to 1 |
```text
$ kubectl -n s14 exec dns-client -- nslookup web-servce.s14.svc.cluster.local 2>&1 | tail -n 3
** server can't find web-servce.s14.svc.cluster.local: NXDOMAIN

command terminated with exit code 1

$ echo "--- wrong name (typo) -> NXDOMAIN; correct name:"; kubectl -n s14 exec dns-client -- nslookup web-service.s14.svc.cluster.local | tail -n 3
--- wrong name (typo) -> NXDOMAIN; correct name:
Name:	web-service.s14.svc.cluster.local
Address: 10.102.110.113


$ echo "--- cross-namespace short name fails, qualified name works:"; kubectl -n s14 exec dns-client -- curl -s -m 3 -o /dev/null -w "HTTP %{http_code}\n" http://kub
--- cross-namespace short name fails, qualified name works:
HTTP 000
command terminated with exit code 28
short name kube-dns (other namespace) -> FAILED
kube-dns.kube-system -> resolved, HTTP 200

$ kubectl -n s14 exec dns-client -- cat /etc/resolv.conf; kubectl -n kube-system get pods -l k8s-app=kube-dns; kubectl -n kube-system get svc kube-dns
search s14.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
NAME                       READY   STATUS    RESTARTS   AGE
coredns-559f6c778d-jhrgf   1/1     Running   0          42m
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   18d

$ echo "--- simulate CoreDNS outage"; kubectl -n kube-system scale deploy coredns --replicas=0; sleep 6; kubectl -n s14 exec dns-client -- nslookup -timeout=2 web-se
--- simulate CoreDNS outage
deployment.apps/coredns scaled

command terminated with exit code 1
by NAME: HTTP 000
command terminated with exit code 28
by NAME: FAILED (could not resolve host)
by IP (ClusterIP) still works:
HTTP 200

$ echo "--- FIX: restore CoreDNS"; kubectl -n kube-system scale deploy coredns --replicas=1; kubectl -n kube-system rollout status deploy/coredns --timeout=90s; slee
--- FIX: restore CoreDNS
deployment.apps/coredns scaled
deployment "coredns" successfully rolled out
Address: 10.102.110.113
```

## 7. Pod networking issues
| | |
|---|---|
| Identify | `curl` from `net-client` to `net-server` times out (exit 28) |
| Investigate | Pod-to-Pod by IP worked before; then `kubectl get networkpolicy` → `deny-all-ingress` selecting `app=net-server` |
| Root cause | A NetworkPolicy with `policyTypes: [Ingress]` and no `ingress` rules denies all incoming traffic to the selected Pod |
| Fix | Add an `ingress.from` rule allowing the client (or delete the policy) |
| Verify | HTTP 200 again |
```text
$ kubectl -n s14 apply -f 02-issues/pod-networking/server.yaml; kubectl -n s14 wait --for=condition=Ready pod/net-server pod/net-client --timeout=90s; kubectl -n s14
pod/net-server created
pod/net-client created
pod/net-server condition met
pod/net-client condition met
net-client             1/1     Running   0          0s      10.244.0.196   minikube   <none>           <none>
net-server             1/1     Running   0          0s      10.244.0.197   minikube   <none>           <none>

$ SIP=$(kubectl -n s14 get pod net-server -o jsonpath="{.status.podIP}"); echo "server IP $SIP"; kubectl -n s14 exec net-client -- curl -s -m 4 -o /dev/null -w "pod 
server IP 10.244.0.197
pod -> pod by IP: HTTP 200

$ cat <<YAML | kubectl -n s14 apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector:
    matchLabels:
      app: net-server
  policyTypes: ["Ingress"]
YAML
sleep 5; kubectl -n s14 get networkpolicy
networkpolicy.networking.k8s.io/deny-all-ingress created
NAME               POD-SELECTOR     AGE
deny-all-ingress   app=net-server   5s

$ SIP=$(kubectl -n s14 get pod net-server -o jsonpath="{.status.podIP}"); kubectl -n s14 exec net-client -- curl -s -m 4 -o /dev/null -w "HTTP %{http_code}\n" http:/
HTTP 000
command terminated with exit code 28
-> pod-to-pod BLOCKED (timeout) while the NetworkPolicy exists

$ kubectl -n s14 describe networkpolicy deny-all-ingress | head -n 12
Name:         deny-all-ingress
Namespace:    s14
Created on:   2026-10-07 23:42:59 +0530 IST
Labels:       <none>
Annotations:  <none>
Spec:
  PodSelector:     app=net-server
  Allowing ingress traffic:
    <none> (Selected pods are isolated for ingress connectivity)
  Not affecting egress traffic
  Policy Types: Ingress

$ echo "--- FIX: delete/adjust the policy (allow client -> server)"; cat <<YAML | kubectl -n s14 apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector:
    matchLabels:
      app: net-server
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: net-client
YAML
sleep 5; SIP=$(kubectl -n s14 get pod net-server -o jsonpath="{.status.podIP}"); kubectl -n s14 exec net-client -- curl -s -m 4 -o /dev/null -w "HTTP %{http_code}\n"
--- FIX: delete/adjust the policy (allow client -> server)
networkpolicy.networking.k8s.io/deny-all-ingress configured
HTTP 200
```

## 8. Configuration issues
| | |
|---|---|
| Identify | `STATUS CreateContainerConfigError` |
| Investigate | `describe` → `Error: couldn't find key DB_HOST in ConfigMap s14/app-settings` |
| Root cause | The Pod references a ConfigMap **key** that does not exist (same class of problem: missing Secret, wrong name, wrong namespace) |
| Fix | Add the key `DB_HOST` to the ConfigMap, recreate the Pod |
| Verify | `Running`, logs show `LOG_LEVEL=info DB_HOST=mysql.default.svc` |
```text
$ kubectl -n s14 apply -f 02-issues/configuration/broken.yaml; sleep 8; kubectl -n s14 get pod config-demo
configmap/app-settings created
pod/config-demo created
NAME          READY   STATUS                       RESTARTS   AGE
config-demo   0/1     CreateContainerConfigError   0          8s

$ kubectl -n s14 describe pod config-demo | grep -E "Status:|State|Reason|Error|couldn.t find key" | cut -c1-200; kubectl -n s14 get configmap app-settings -o jsonpa
Status:           Pending
    State:          Waiting
      Reason:       CreateContainerConfigError
  Type     Reason     Age              From               Message
  Warning  Failed     7s (x2 over 8s)  kubelet            spec.containers{app}: Error: couldn't find key DB_HOST in ConfigMap s14/app-settings
{"LOG_LEVEL":"info"}

$ echo "--- FIX: add the missing key to the ConfigMap (Pod retries automatically)"; kubectl -n s14 patch configmap app-settings --type merge -p "{\"data\":{\"DB_HOST
--- FIX: add the missing key to the ConfigMap (Pod retries automatically)
configmap/app-settings patched
pod "config-demo" deleted from s14 namespace
pod/config-demo condition met
NAME          READY   STATUS    RESTARTS   AGE
config-demo   1/1     Running   0          0s
LOG_LEVEL=info DB_HOST=mysql.default.svc
```

## 9. Bonus – OOMKilled
| | |
|---|---|
| Identify | `STATUS OOMKilled`, restarts increasing |
| Investigate | `describe` → `Reason: OOMKilled`, `Exit Code: 137`, `Limits memory: 20Mi` |
| Root cause | The process allocates more memory than the container limit, the kernel OOM-killer terminates it |
| Fix | Raise the limit / fix the leak |
| Verify | Pod `Running` |
```text
$ kubectl -n s14 apply -f 02-issues/oomkilled/broken.yaml; sleep 20; kubectl -n s14 get pod fail-5-oomkilled-pod
pod/fail-5-oomkilled-pod created
NAME                   READY   STATUS      RESTARTS      AGE
fail-5-oomkilled-pod   0/1     OOMKilled   2 (19s ago)   20s

$ kubectl -n s14 describe pod fail-5-oomkilled-pod | grep -E "State|Reason|Exit Code|Limits|memory:|Restart" | head -n 9
    State:          Terminated
      Reason:       OOMKilled
      Exit Code:    137
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
    Restart Count:  2
    Limits:
      memory:  20Mi

$ echo "--- FIX: raise the memory limit / fix the leak"; kubectl -n s14 delete pod fail-5-oomkilled-pod --wait=true; kubectl -n s14 apply -f 02-issues/oomkilled/fixe
--- FIX: raise the memory limit / fix the leak
pod "fail-5-oomkilled-pod" deleted from s14 namespace
pod/fail-5-oomkilled-pod created
pod/fail-5-oomkilled-pod condition met
NAME                   READY   STATUS    RESTARTS   AGE
fail-5-oomkilled-pod   1/1     Running   0          0s
```

---
# Task 3 – Mini project
Deployment `troubleshooting-app` (2× nginx) + Service `troubleshooting-service`, then two deliberately introduced problems (a broken image and a wrong Service selector). Files: [`mini-project/`](mini-project/).

```text
$ kubectl -n s14m apply -f deployment.yaml -f service.yaml; kubectl -n s14m rollout status deploy/troubleshooting-app --timeout=120s; kubectl -n s14m get pods; kubectl 
deployment.apps/troubleshooting-app created
service/troubleshooting-service created
deployment "troubleshooting-app" successfully rolled out
NAME                                   READY   STATUS    RESTARTS   AGE
troubleshooting-app-59d4957864-hgb65   1/1     Running   0          1s
troubleshooting-app-59d4957864-jvh6f   1/1     Running   0          1s
NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
troubleshooting-service   ClusterIP   10.107.114.9   <none>        80/TCP    1s

$ kubectl -n s14m get pods -o wide; POD=$(kubectl -n s14m get pods -o jsonpath="{.items[0].metadata.name}"); kubectl -n s14m describe pod $POD | sed -n "1,12p;/Events:/
NAME                                   READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
troubleshooting-app-59d4957864-hgb65   1/1     Running   0          1s    10.244.0.208   minikube   <none>           <none>
troubleshooting-app-59d4957864-jvh6f   1/1     Running   0          1s    10.244.0.207   minikube   <none>           <none>
Name:             troubleshooting-app-59d4957864-hgb65
Namespace:        s14m
Priority:         0
Service Account:  default
Node:             minikube/192.168.49.2
Start Time:       Wed, 07 Oct 2026 23:44:59 +0530
Labels:           app=troubleshooting-app
                  pod-template-hash=59d4957864
Annotations:      <none>
Status:           Running
IP:               10.244.0.208
IPs:
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  0s    default-scheduler  Successfully assigned s14m/troubleshooting-app-59d4957864-hgb65 to minikube
  Normal  Pulled     0s    kubelet            spec.containers{app}: Container image "nginx:1.27" already present on machine and can be accessed by the pod
  Normal  Created    0s    kubelet            spec.containers{app}: Container created
  Normal  Started    0s    kubelet            spec.containers{app}: Container started

$ POD=$(kubectl -n s14m get pods -o jsonpath="{.items[0].metadata.name}"); kubectl -n s14m logs $POD | tail -n 3; kubectl -n s14m exec $POD -- curl -s -o /dev/null -w "
2026/10/07 18:15:00 [notice] 1#1: start worker process 37
2026/10/07 18:15:00 [notice] 1#1: start worker process 38
2026/10/07 18:15:00 [notice] 1#1: start worker process 39
curl localhost -> HTTP 200

$ kubectl -n s14m describe service troubleshooting-service | grep -E "Name:|Selector|Port|TargetPort|Endpoints"; kubectl -n s14m get endpoints troubleshooting-service
Name:                     troubleshooting-service
Selector:                 app=troubleshooting-app
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
Endpoints:                10.244.0.207:80,10.244.0.208:80
NAME                      ENDPOINTS                         AGE
troubleshooting-service   10.244.0.207:80,10.244.0.208:80   1s

--- 5-7. Broken Pod
$ kubectl -n s14m apply -f broken-pod.yaml; sleep 25; kubectl -n s14m get pod project-broken-pod
pod/project-broken-pod created
NAME                 READY   STATUS             RESTARTS   AGE
project-broken-pod   0/1     ImagePullBackOff   0          25s

$ kubectl -n s14m describe pod project-broken-pod | sed -n "/State:/,/Ready:/p;/Events:/,\$p" | cut -c1-210
    State:          Waiting
      Reason:       ImagePullBackOff
    Ready:          False
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  25s               default-scheduler  Successfully assigned s14m/project-broken-pod to minikube
  Warning  Failed     16s               kubelet            spec.containers{app}: Failed to pull image "nginx:this-tag-does-not-exist": failed to pull and unpack imag
  Warning  Failed     16s               kubelet            spec.containers{app}: Error: ErrImagePull
  Normal   BackOff    15s               kubelet            spec.containers{app}: Back-off pulling image "nginx:this-tag-does-not-exist"
  Warning  Failed     15s               kubelet            spec.containers{app}: Error: ImagePullBackOff
  Normal   Pulling    5s (x2 over 24s)  kubelet            spec.containers{app}: Pulling image "nginx:this-tag-does-not-exist"

$ echo "--- FIX: use an existing image tag"; kubectl -n s14m delete pod project-broken-pod --wait=true; sed "s/nginx:this-tag-does-not-exist/nginx:1.27/" broken-pod.y
--- FIX: use an existing image tag
pod "project-broken-pod" deleted from s14m namespace
pod/project-broken-pod created
pod/project-broken-pod condition met
NAME                 READY   STATUS    RESTARTS   AGE
project-broken-pod   1/1     Running   0          1s

--- 8-9. Service selector problem
$ kubectl -n s14m get service troubleshooting-service -o jsonpath="{.spec.selector}"; echo; kubectl -n s14m patch service troubleshooting-service --type merge -p "{\"s
{"app":"troubleshooting-app"}
service/troubleshooting-service patched
NAME                      TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
troubleshooting-service   ClusterIP   10.107.114.9   <none>        80/TCP    35s
NAME                      ENDPOINTS   AGE
troubleshooting-service   <none>      35s

$ kubectl -n s14m get pods --show-labels | grep troubleshooting-app; kubectl -n s14m describe service troubleshooting-service | grep -E "Selector|Endpoints"; kubectl -
troubleshooting-app-59d4957864-hgb65   1/1     Running   0          35s   app=troubleshooting-app,pod-template-hash=59d4957864
troubleshooting-app-59d4957864-jvh6f   1/1     Running   0          35s   app=troubleshooting-app,pod-template-hash=59d4957864
Selector:                 app=wrong-app
Endpoints:                
pod "svc-test" deleted from s14m namespace
pod s14m/svc-test terminated (Error)

$ echo "--- FIX: selector back to app: troubleshooting-app"; kubectl -n s14m patch service troubleshooting-service --type merge -p "{\"spec\":{\"selector\":{\"app\":\
--- FIX: selector back to app: troubleshooting-app
service/troubleshooting-service patched
NAME                      ENDPOINTS                         AGE
troubleshooting-service   10.244.0.207:80,10.244.0.208:80   40s
Address: 10.107.114.9

HTTP 200
Address: 10.107.114.9

HTTP 200
pod "svc-test2" deleted from s14m namespace

$ kubectl -n s14m get pods,svc,endpoints
NAME                                       READY   STATUS    RESTARTS   AGE
pod/project-broken-pod                     1/1     Running   0          11s
pod/troubleshooting-app-59d4957864-hgb65   1/1     Running   0          43s
pod/troubleshooting-app-59d4957864-jvh6f   1/1     Running   0          43s

NAME                              TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/troubleshooting-service   ClusterIP   10.107.114.9   <none>        80/TCP    43s

NAME                                ENDPOINTS                         AGE
endpoints/troubleshooting-service   10.244.0.207:80,10.244.0.208:80   43s
```

## Questions (step 7)
1. **Pod status?** `ImagePullBackOff` (preceded by `ErrImagePull`).
2. **Actual error?** `Failed to pull image "nginx:this-tag-does-not-exist": … not found`.
3. **Which command found it?** `kubectl describe pod project-broken-pod` (the **Events** section; `kubectl get pod` only shows the status).
4. **What is wrong with the image?** The tag `this-tag-does-not-exist` does not exist in the `nginx` repository.
5. **How to fix?** Use a valid tag (e.g. `nginx:1.27`) and recreate the Pod.

## Troubleshooting table
| Problem | What I Saw | Command I Used | Root Cause | Fix |
|---|---|---|---|---|
| **Broken Pod** | `ImagePullBackOff`, 0/1 ready | `get pod`, `describe pod`, `events` | wrong image tag | correct image tag `nginx:1.27`, recreate |
| **Service Problem** | `ENDPOINTS <none>`, curl fails | `get endpoints`, `get pods --show-labels`, `describe svc` | Service selector `app=wrong-app` ≠ Pod label `app=troubleshooting-app` | patch selector back |
| **Image Problem** | `Failed to pull image … NotFound` in Events | `describe pod`, `events --for pod/<name>` | non-existent tag | use existing tag |

## README questions
1. **What does `kubectl get` tell us?** The list of resources and their current status (ready, restarts, age, node, IP with `-o wide`).
2. **`get` vs `describe`?** `get` = compact status table; `describe` = full detail incl. events, conditions, probes, volumes – the *why*.
3. **Why `kubectl logs`?** To read the application's stdout/stderr – startup errors, exceptions, why a container crashed (`--previous`).
4. **When use `kubectl exec`?** To inspect from inside: test connectivity (`curl`, `nslookup`), check files, env vars, processes, config actually mounted.
5. **`CrashLoopBackOff`?** The container starts, exits, and is restarted repeatedly; kubelet waits longer between restarts (10 s, 20 s … max 5 min). Cause is in the app/command/config – read `logs --previous`.
6. **`ImagePullBackOff`?** Kubernetes cannot pull the image (wrong name/tag, no access, registry unreachable) and is backing off between retries (`ErrImagePull` is the failed attempt).
7. **Why can a Pod stay `Pending`?** No node satisfies it: insufficient CPU/memory, `nodeSelector`/affinity mismatch, taints without tolerations, unbound PVC, or no nodes ready.
8. **Why can a Service have no endpoints?** Its selector matches no **Ready** Pods (label mismatch, Pods not ready/failing readiness probe, wrong namespace, no Pods).
9. **Service selector ↔ Pod labels?** The Service continuously selects Pods whose labels match its `selector`; those Pod IPs become its endpoints. If labels and selector differ, no traffic is routed.
10. **What is Kubernetes DNS?** CoreDNS gives every Service (and Pod) a name (`svc.ns.svc.cluster.local`) so workloads find each other by name instead of changing IPs.

## Final checklist
```bash
kubectl get pods                      # status
kubectl describe pod <pod-name>       # events & details
kubectl logs <pod-name> [--previous]  # app output
kubectl exec -it <pod-name> -- sh     # look inside
kubectl get events --sort-by=.metadata.creationTimestamp
# Services
kubectl describe service <svc>; kubectl get endpoints <svc>; nslookup <svc>
```
