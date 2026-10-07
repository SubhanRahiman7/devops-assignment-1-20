# Session 10 – Deployment Strategies & Pod Lifecycle

Cluster: Minikube (Kubernetes v1.37, arm64, containerd). All demos run in namespace `s10`. Traffic is tested from a `curl` Pod inside the cluster (Docker-driver NodePorts are not reachable from the macOS host). The YAML files are in the sub-folders next to this README.

# Task 1 – Deployment Strategies

## 01. Rolling Update → [`01-rolling-update/`](01-rolling-update/)
`strategy: RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 0`: Kubernetes adds one new Pod, waits until it is Ready, then removes one old Pod – capacity never drops below 4 and there is no downtime. v1 = `nginx:1.24-alpine`, v2 = `nginx:1.25-alpine`.
```text
$ kubectl -n s10 apply -f 01-rolling-update/deployment-v1.yaml -f 01-rolling-update/service.yaml
deployment.apps/app-rolling created
service/app-rolling-service created

$ kubectl -n s10 rollout status deployment/app-rolling --timeout=180s; kubectl -n s10 get pods -l app=app-rolling --show-labels
deployment "app-rolling" successfully rolled out
NAME                           READY   STATUS    RESTARTS   AGE   LABELS
app-rolling-86d7d44d5b-49mwx   1/1     Running   0          7s    app=app-rolling,pod-template-hash=86d7d44d5b,version=v1
app-rolling-86d7d44d5b-8wskg   1/1     Running   0          7s    app=app-rolling,pod-template-hash=86d7d44d5b,version=v1
app-rolling-86d7d44d5b-fzpb6   1/1     Running   0          7s    app=app-rolling,pod-template-hash=86d7d44d5b,version=v1
app-rolling-86d7d44d5b-prkzj   1/1     Running   0          7s    app=app-rolling,pod-template-hash=86d7d44d5b,version=v1

$ kubectl -n s10 exec tester -- curl -s http://app-rolling-service | grep -io "version: v[0-9]"
VERSION: v1

$ kubectl -n s10 apply -f 01-rolling-update/deployment-v2.yaml
deployment.apps/app-rolling configured

$ kubectl -n s10 rollout status deployment/app-rolling --timeout=240s
deployment "app-rolling" successfully rolled out

$ kubectl get pods -l app=app-rolling -w   (captured during the update)
app-rolling-86d7d44d5b-49mwx  1/1  Running            7s
app-rolling-86d7d44d5b-8wskg  1/1  Running            7s
app-rolling-86d7d44d5b-fzpb6  1/1  Running            7s
app-rolling-86d7d44d5b-prkzj  1/1  Running            7s
app-rolling-56bff6d88c-8fc2k  0/1  Pending            0s
app-rolling-56bff6d88c-8fc2k  0/1  ContainerCreating  0s
app-rolling-56bff6d88c-8fc2k  0/1  Running            1s
app-rolling-56bff6d88c-8fc2k  1/1  Running            7s
app-rolling-86d7d44d5b-8wskg  1/1  Terminating        14s
app-rolling-56bff6d88c-mhb9k  0/1  Pending            0s
app-rolling-56bff6d88c-mhb9k  0/1  ContainerCreating  0s
app-rolling-86d7d44d5b-8wskg  0/1  Completed          14s
app-rolling-56bff6d88c-mhb9k  0/1  ContainerCreating  0s
app-rolling-56bff6d88c-mhb9k  0/1  Running            0s
app-rolling-86d7d44d5b-8wskg  0/1  Completed          15s
app-rolling-56bff6d88c-mhb9k  1/1  Running            6s
app-rolling-86d7d44d5b-49mwx  1/1  Terminating        20s
app-rolling-56bff6d88c-l5khj  0/1  Pending            0s
app-rolling-86d7d44d5b-49mwx  1/1  Terminating        20s
app-rolling-56bff6d88c-l5khj  0/1  Pending            0s
app-rolling-56bff6d88c-l5khj  0/1  ContainerCreating  0s
app-rolling-86d7d44d5b-49mwx  0/1  Completed          20s
app-rolling-56bff6d88c-l5khj  0/1  ContainerCreating  0s
app-rolling-56bff6d88c-l5khj  0/1  Running            0s
app-rolling-86d7d44d5b-49mwx  0/1  Completed          21s
app-rolling-56bff6d88c-l5khj  1/1  Running            6s
app-rolling-86d7d44d5b-prkzj  1/1  Terminating        26s
app-rolling-56bff6d88c-42w27  0/1  Pending            0s
app-rolling-86d7d44d5b-prkzj  1/1  Terminating        26s
app-rolling-56bff6d88c-42w27  0/1  Pending            0s
app-rolling-56bff6d88c-42w27  0/1  ContainerCreating  0s
app-rolling-86d7d44d5b-prkzj  0/1  Completed          26s
app-rolling-56bff6d88c-42w27  0/1  ContainerCreating  0s
app-rolling-56bff6d88c-42w27  0/1  Running            0s
app-rolling-86d7d44d5b-prkzj  0/1  Completed          27s
app-rolling-56bff6d88c-42w27  1/1  Running            6s
app-rolling-86d7d44d5b-fzpb6  1/1  Terminating        32s
app-rolling-86d7d44d5b-fzpb6  0/1  Completed          32s

$ kubectl -n s10 get pods -l app=app-rolling --show-labels; kubectl -n s10 get rs -l app=app-rolling
NAME                           READY   STATUS    RESTARTS   AGE   LABELS
app-rolling-56bff6d88c-42w27   1/1     Running   0          8s    app=app-rolling,pod-template-hash=56bff6d88c,version=v2
app-rolling-56bff6d88c-8fc2k   1/1     Running   0          27s   app=app-rolling,pod-template-hash=56bff6d88c,version=v2
app-rolling-56bff6d88c-l5khj   1/1     Running   0          14s   app=app-rolling,pod-template-hash=56bff6d88c,version=v2
app-rolling-56bff6d88c-mhb9k   1/1     Running   0          20s   app=app-rolling,pod-template-hash=56bff6d88c,version=v2
NAME                     DESIRED   CURRENT   READY   AGE
app-rolling-56bff6d88c   4         4         4       27s
app-rolling-86d7d44d5b   0         0         0       34s

$ kubectl -n s10 exec tester -- curl -s http://app-rolling-service | grep -io "version: v[0-9]"
VERSION: v2

$ kubectl -n s10 rollout history deployment/app-rolling
deployment.apps/app-rolling 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>


$ kubectl -n s10 rollout undo deployment/app-rolling; kubectl -n s10 rollout status deployment/app-rolling --timeout=240s; kubectl -n s10 exec tester -- curl -s http://app-rolling-service | grep -io "version: v[0-9]"
Warning: resource deployments/app-rolling was previously managed with 'kubectl apply'. Rolling back will not update the kubectl.kubernetes.io/last-applied-configuration annotation, which may cause unexpected behavior on future 'kubectl apply' operations. Consider using 'kubectl apply' with your previous configuration file instead.
deployment.apps/app-rolling rolled back
deployment "app-rolling" successfully rolled out
VERSION: v1
```
**Verified:** v1 Pods (ReplicaSet `86d7…`) were replaced one by one by v2 Pods (`56bf…`); the old ReplicaSet stays at 0 replicas for rollback; `rollout undo` returned to v1.

## 02. Blue-Green → [`02-blue-green/`](02-blue-green/)
Two full Deployments (`app-blue` v1, `app-green` v2) run side by side and one Service selects `slot: blue`. **Switching traffic = changing the Service selector** to `slot: green` (instant; rollback is instant too).
```text
$ kubectl -n s10 apply -f 02-blue-green/deployment-blue.yaml -f 02-blue-green/deployment-green.yaml -f 02-blue-green/service-blue.yaml
deployment.apps/app-blue created
deployment.apps/app-green created
service/myapp-service created

$ kubectl -n s10 rollout status deployment/app-blue --timeout=180s; kubectl -n s10 rollout status deployment/app-green --timeout=180s; kubectl -n s10 get pods -l app=myapp --show-labels
deployment "app-blue" successfully rolled out
deployment "app-green" successfully rolled out
NAME                        READY   STATUS    RESTARTS   AGE   LABELS
app-blue-5c69d7785c-2pbm4   1/1     Running   0          7s    app=myapp,pod-template-hash=5c69d7785c,slot=blue,version=v1
app-blue-5c69d7785c-765sb   1/1     Running   0          7s    app=myapp,pod-template-hash=5c69d7785c,slot=blue,version=v1
app-blue-5c69d7785c-88z2h   1/1     Running   0          7s    app=myapp,pod-template-hash=5c69d7785c,slot=blue,version=v1
app-green-84df7f978-d79cm   1/1     Running   0          7s    app=myapp,pod-template-hash=84df7f978,slot=green,version=v2
app-green-84df7f978-ltgmh   1/1     Running   0          7s    app=myapp,pod-template-hash=84df7f978,slot=green,version=v2
app-green-84df7f978-qmppj   1/1     Running   0          7s    app=myapp,pod-template-hash=84df7f978,slot=green,version=v2

$ kubectl -n s10 get svc myapp-service -o jsonpath="{.spec.selector}"; echo; kubectl -n s10 get endpoints myapp-service
{"app":"myapp","slot":"blue"}
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME            ENDPOINTS                                      AGE
myapp-service   10.244.0.60:80,10.244.0.61:80,10.244.0.62:80   7s

$ echo "--- 6 requests while Service -> BLUE:"; for i in 1 2 3 4 5 6; do kubectl -n s10 exec tester -- curl -s http://myapp-service | grep -o "[A-Z]* ENVIRONMENT"; done | sort | uniq -c
--- 6 requests while Service -> BLUE:
   6 BLUE ENVIRONMENT

$ grep -A3 "selector:" 02-blue-green/service-green.yaml; kubectl -n s10 apply -f 02-blue-green/service-green.yaml; sleep 4
  selector:
    app: myapp
    slot: green    # <-- NOW routing to GREEN (v2)
  ports:
service/myapp-service configured

$ kubectl -n s10 get svc myapp-service -o jsonpath="{.spec.selector}"; echo; kubectl -n s10 get endpoints myapp-service; echo "--- 6 requests after switch:"; for i in 1 2 3 4 5 6; do kubectl -n s10 exec tester -- curl -s http://myapp-service | grep -o "[A-Z]* ENVIRONMENT"; done | sort | uniq -c
{"app":"myapp","slot":"green"}
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME            ENDPOINTS                                      AGE
myapp-service   10.244.0.63:80,10.244.0.64:80,10.244.0.65:80   12s
--- 6 requests after switch:
   6 GREEN ENVIRONMENT

$ echo "--- instant rollback to BLUE:"; kubectl -n s10 apply -f 02-blue-green/service-blue.yaml; sleep 4; kubectl -n s10 exec tester -- curl -s http://myapp-service | grep -o "[A-Z]* ENVIRONMENT"
--- instant rollback to BLUE:
service/myapp-service configured
BLUE ENVIRONMENT
```

## 03. Canary → [`03-canary/`](03-canary/)
Stable (9 Pods) and canary (1 Pod) share the label `app: myapp-canary`; the Service load-balances across all Pods, so traffic share ≈ pod ratio (10 %, then 30 % after scaling to 3 canary / 7 stable). kube-proxy picks endpoints randomly, so the sample counts are approximate.
```text
$ kubectl -n s10 apply -f 03-canary/deployment-stable.yaml -f 03-canary/deployment-canary.yaml -f 03-canary/service.yaml
deployment.apps/app-stable created
deployment.apps/app-canary created
service/myapp-canary-service created

$ kubectl -n s10 rollout status deployment/app-stable --timeout=180s; kubectl -n s10 rollout status deployment/app-canary --timeout=180s; kubectl -n s10 get pods -l app=myapp-canary --show-labels | sed "s/pod-template-hash=[a-z0-9]*,//"
deployment "app-stable" successfully rolled out
deployment "app-canary" successfully rolled out
NAME                          READY   STATUS    RESTARTS   AGE   LABELS
app-canary-5849994497-d7pt9   1/1     Running   0          8s    app=myapp-canary,track=canary,version=v2
app-stable-6ffb777f9d-4jwlw   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-5g6hb   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-5pxlw   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-7vm8g   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-cgznt   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-f22nq   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-nljwf   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-x8vjl   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1
app-stable-6ffb777f9d-xc77x   1/1     Running   0          8s    app=myapp-canary,track=stable,version=v1

$ kubectl -n s10 get endpoints myapp-canary-service
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                   ENDPOINTS                                                  AGE
myapp-canary-service   10.244.0.66:80,10.244.0.67:80,10.244.0.68:80 + 7 more...   8s

$ echo "--- 50 requests through the Service:"; for i in $(seq 1 50); do kubectl -n s10 exec tester -- curl -s http://myapp-canary-service | grep -oE "CANARY v2|STABLE v1|v1|v2" | head -1; done | sort | uniq -c
--- 50 requests through the Service:
   2 CANARY v2
  48 STABLE v1

$ kubectl -n s10 scale deployment app-canary --replicas=3; kubectl -n s10 scale deployment app-stable --replicas=7; kubectl -n s10 rollout status deployment/app-canary --timeout=120s; kubectl -n s10 rollout status deployment/app-stable --timeout=120s; kubectl -n s10 get pods -l app=myapp-canary -L track --no-headers | awk "{print \$NF}" | sort | uniq -c
deployment.apps/app-canary scaled
deployment.apps/app-stable scaled
deployment "app-canary" successfully rolled out
deployment "app-stable" successfully rolled out
   3 canary
   7 stable

$ echo "--- 50 requests after increasing canary to 3/10:"; for i in $(seq 1 50); do kubectl -n s10 exec tester -- curl -s http://myapp-canary-service | grep -oE "CANARY v2|STABLE v1|v1|v2" | head -1; done | sort | uniq -c
--- 50 requests after increasing canary to 3/10:
  10 CANARY v2
  40 STABLE v1
```

## 04. Recreate → [`04-recreate/`](04-recreate/)
`strategy: Recreate`: **all** old Pods are terminated first and only then are new Pods created → short downtime, but never two versions at once (for versions that cannot coexist, e.g. DB schema changes).
```text
$ kubectl -n s10 apply -f 04-recreate/deployment-v1.yaml -f 04-recreate/service.yaml; kubectl -n s10 rollout status deployment/app-recreate --timeout=180s; kubectl -n s10 get pods -l app=app-recreate --show-labels | sed "s/pod-template-hash=[a-z0-9]*,//"
deployment.apps/app-recreate created
service/app-recreate-service created
deployment "app-recreate" successfully rolled out
NAME                            READY   STATUS    RESTARTS   AGE   LABELS
app-recreate-6c78cb55bb-4bmcm   1/1     Running   0          1s    app=app-recreate,version=v1
app-recreate-6c78cb55bb-5x96k   1/1     Running   0          1s    app=app-recreate,version=v1
app-recreate-6c78cb55bb-6wzsh   1/1     Running   0          1s    app=app-recreate,version=v1

$ kubectl -n s10 get deployment app-recreate -o jsonpath="{.spec.strategy}"; echo; kubectl -n s10 exec tester -- curl -s http://app-recreate-service | grep -io "version: v[0-9]"
{"type":"Recreate"}
command terminated with exit code 7

$ kubectl -n s10 apply -f 04-recreate/deployment-v2.yaml; kubectl -n s10 rollout status deployment/app-recreate --timeout=240s
deployment.apps/app-recreate configured
deployment "app-recreate" successfully rolled out

$ kubectl get pods -l app=app-recreate -w   (captured during the update)
app-recreate-6c78cb55bb-4bmcm  1/1  Running
app-recreate-6c78cb55bb-5x96k  1/1  Running
app-recreate-6c78cb55bb-6wzsh  1/1  Running
app-recreate-6c78cb55bb-4bmcm  1/1  Terminating
app-recreate-6c78cb55bb-5x96k  1/1  Terminating
app-recreate-6c78cb55bb-6wzsh  1/1  Terminating
app-recreate-6c78cb55bb-4bmcm  1/1  Terminating
app-recreate-6c78cb55bb-5x96k  1/1  Terminating
app-recreate-6c78cb55bb-6wzsh  1/1  Terminating
app-recreate-6c78cb55bb-6wzsh  0/1  Completed
app-recreate-6c78cb55bb-5x96k  0/1  Completed
app-recreate-6c78cb55bb-4bmcm  0/1  Completed
app-recreate-7bd8d89b8b-cdkr5  0/1  Pending
app-recreate-7bd8d89b8b-c6b5h  0/1  Pending
app-recreate-7bd8d89b8b-fjmh7  0/1  Pending
app-recreate-7bd8d89b8b-c6b5h  0/1  Pending
app-recreate-7bd8d89b8b-fjmh7  0/1  Pending
app-recreate-7bd8d89b8b-cdkr5  0/1  ContainerCreating
app-recreate-7bd8d89b8b-c6b5h  0/1  ContainerCreating
app-recreate-7bd8d89b8b-fjmh7  0/1  ContainerCreating
app-recreate-7bd8d89b8b-c6b5h  0/1  ContainerCreating
app-recreate-7bd8d89b8b-cdkr5  0/1  ContainerCreating
app-recreate-7bd8d89b8b-fjmh7  0/1  ContainerCreating
app-recreate-6c78cb55bb-5x96k  0/1  Completed
app-recreate-6c78cb55bb-4bmcm  0/1  Completed
app-recreate-7bd8d89b8b-cdkr5  1/1  Running
app-recreate-6c78cb55bb-6wzsh  0/1  Completed
app-recreate-7bd8d89b8b-c6b5h  1/1  Running
app-recreate-7bd8d89b8b-fjmh7  1/1  Running

$ kubectl -n s10 get pods -l app=app-recreate --show-labels | sed "s/pod-template-hash=[a-z0-9]*,//"; kubectl -n s10 get rs -l app=app-recreate; kubectl -n s10 exec tester -- curl -s http://app-recreate-service | grep -io "version: v[0-9]"
NAME                            READY   STATUS    RESTARTS   AGE   LABELS
app-recreate-7bd8d89b8b-c6b5h   1/1     Running   0          3s    app=app-recreate,version=v2
app-recreate-7bd8d89b8b-cdkr5   1/1     Running   0          3s    app=app-recreate,version=v2
app-recreate-7bd8d89b8b-fjmh7   1/1     Running   0          3s    app=app-recreate,version=v2
NAME                      DESIRED   CURRENT   READY   AGE
app-recreate-6c78cb55bb   0         0         0       5s
app-recreate-7bd8d89b8b   3         3         3       3s
VERSION: v2
```
**Verified:** in the watch output every `app-recreate-6c78…` (v1) Pod goes `Terminating → Completed` **before** any `app-recreate-7bd8…` (v2) Pod appears as `Pending`. (The `exit code 7` right after the first rollout is `curl` hitting the Service in the first second before kube-proxy had endpoints – this Deployment has no readiness probe.)

# Task 2 – Pod Lifecycle → [`pod-lifecycle/`](pod-lifecycle/)
For each YAML: `kubectl apply -f` → `kubectl get pod` → `kubectl describe pod` (key fields + events) → logs where useful.

### 01 RUNNING
**Observation:** `Running` – container started, `Ready: True`.
```text
$ kubectl apply -f 01-running.yaml
pod/lifecycle-running created
$ kubectl get pod lifecycle-running   (after ready)
NAME                READY   STATUS    RESTARTS   AGE
lifecycle-running   1/1     Running   0          0s
$ kubectl describe pod lifecycle-running   (key fields)
Status: Running
State: Running
Ready: True
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 0s default-scheduler Successfully assigned s10/lifecycle-running to minikube
Normal Pulled 0s kubelet spec.containers{nginx}: Container image "nginx:1.27" already present on machine and can be accessed by the pod
Normal Created 0s kubelet spec.containers{nginx}: Container created
Normal Started 0s kubelet spec.containers{nginx}: Container started
```

### 02 PENDING
**Observation:** `Pending` – the scheduler could not place the Pod (it requests 9Gi memory, the node has ~8Gi) → event `FailedScheduling: Insufficient memory`.
```text
$ kubectl apply -f 02-pending.yaml
pod/lifecycle-pending created
$ kubectl get pod lifecycle-pending   (after 6s)
NAME                READY   STATUS    RESTARTS   AGE
lifecycle-pending   0/1     Pending   0          6s
$ kubectl describe pod lifecycle-pending   (key fields)
Status: Pending
Type Status
Type Reason Age From Message
Warning FailedScheduling 6s default-scheduler 0/1 nodes are available: 1 Insufficient memory. preemption: 0/1 nodes are available: 1 Preemption is not
```

### 03 SUCCEEDED
**Observation:** Pod ran, printed output and exited 0 → phase `Succeeded` (shown as `Completed`).
```text
$ kubectl apply -f 03-succeeded.yaml
pod/lifecycle-succeeded created
$ kubectl get pod lifecycle-succeeded   (after 3s)
NAME                  READY   STATUS    RESTARTS   AGE
lifecycle-succeeded   1/1     Running   0          3s
$ kubectl get pod lifecycle-succeeded   (after 15s)
NAME                  READY   STATUS      RESTARTS   AGE
lifecycle-succeeded   0/1     Completed   0          16s
$ kubectl logs lifecycle-succeeded
Task started
Task completed successfully
Status: Succeeded
State: Terminated
Ready: False
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 15s default-scheduler Successfully assigned s10/lifecycle-succeeded to minikube
Normal Pulled 15s kubelet spec.containers{task}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
Normal Created 15s kubelet spec.containers{task}: Container created
Normal Started 15s kubelet spec.containers{task}: Container started
```

### 04 FAILED
**Observation:** Container exited with code 1 and `restartPolicy: Never` → phase `Failed` (shown as `Error`).
```text
$ kubectl apply -f 04-failed.yaml
pod/lifecycle-failed created
$ kubectl get pod lifecycle-failed   (after 15s)
NAME               READY   STATUS   RESTARTS   AGE
lifecycle-failed   0/1     Error    0          15s
$ kubectl logs lifecycle-failed
Task started
Task failed
Status: Failed
State: Terminated
Ready: False
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 15s default-scheduler Successfully assigned s10/lifecycle-failed to minikube
Normal Pulled 15s kubelet spec.containers{task}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
Normal Created 15s kubelet spec.containers{task}: Container created
Normal Started 15s kubelet spec.containers{task}: Container started
```

### 05 CRASHLOOPBACKOFF
**Observation:** Container exits with code 1 after 3 s; the kubelet restarts it with exponential back-off (`Back-off restarting failed container`). Restart count keeps growing and the Pod alternates between `Running` and `Error` (Kubernetes docs call the waiting state `CrashLoopBackOff`; this Minikube version shows `Error` in the table). See also the extra capture below.
```text
$ kubectl apply -f 05-crashloopbackoff.yaml
pod/lifecycle-crashloop created
$ kubectl get pod lifecycle-crashloop   (after 50s)
NAME                  READY   STATUS    RESTARTS      AGE
lifecycle-crashloop   1/1     Running   3 (25s ago)   50s
$ kubectl logs lifecycle-crashloop
Application started
Status: Running
State: Running
Ready: True
Restart Count: 3
Type Status
Type Reason Age From Message
Normal Scheduled 50s default-scheduler Successfully assigned s10/lifecycle-crashloop to minikube
Warning BackOff 24s (x2 over 42s) kubelet spec.containers{crashing-app}: Back-off restarting failed container crashing-app in pod lifecycle-crashloop_
Normal Pulled 1s (x4 over 50s) kubelet spec.containers{crashing-app}: Container image "busybox:1.36" already present on machine and can be accessed by
Normal Created 1s (x4 over 50s) kubelet spec.containers{crashing-app}: Container created
Normal Started 1s (x4 over 50s) kubelet spec.containers{crashing-app}: Container started
```

### 06 IMAGEPULLBACKOFF
**Observation:** Image does not exist → `ErrImagePull`, then `ImagePullBackOff`, with `Failed to pull image` events.
```text
$ kubectl apply -f 06-imagepullbackoff.yaml
pod/lifecycle-image-error created
$ kubectl get pod lifecycle-image-error   (after 20s)
NAME                    READY   STATUS         RESTARTS   AGE
lifecycle-image-error   0/1     ErrImagePull   0          20s
Status: Pending
State: Waiting
Ready: False
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 20s default-scheduler Successfully assigned s10/lifecycle-image-error to minikube
Warning Failed 14s kubelet spec.containers{broken-image}: Failed to pull image "jakwehrgkaejw:kahsdfgkhj": failed to pull and unpack image "docker.io/
Warning Failed 14s kubelet spec.containers{broken-image}: Error: ErrImagePull
Normal BackOff 13s kubelet spec.containers{broken-image}: Back-off pulling image "jakwehrgkaejw:kahsdfgkhj"
Warning Failed 13s kubelet spec.containers{broken-image}: Error: ImagePullBackOff
Normal Pulling 0s (x2 over 19s) kubelet spec.containers{broken-image}: Pulling image "jakwehrgkaejw:kahsdfgkhj"
```

### 07 READINESS
**Observation:** Container is `Running` but `0/1` Ready until the readiness probe passes (≈5 s) – a not-ready Pod receives no Service traffic.
```text
$ kubectl apply -f 07-readiness.yaml
pod/lifecycle-readiness created
$ kubectl get pod lifecycle-readiness   (after 2s)
NAME                  READY   STATUS    RESTARTS   AGE
lifecycle-readiness   0/1     Running   0          3s
$ kubectl get pod lifecycle-readiness   (after 14s)
NAME                  READY   STATUS    RESTARTS   AGE
lifecycle-readiness   1/1     Running   0          15s
Status: Running
State: Running
Ready: True
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 14s default-scheduler Successfully assigned s10/lifecycle-readiness to minikube
Normal Pulled 14s kubelet spec.containers{nginx}: Container image "nginx:1.27" already present on machine and can be accessed by the pod
Normal Created 14s kubelet spec.containers{nginx}: Container created
Normal Started 14s kubelet spec.containers{nginx}: Container started
```

### 08 LIVENESS
**Observation:** Liveness probe (`test -f /tmp/healthy`) fails once the file is removed → `Liveness probe failed` → kubelet kills and restarts the container (restart count increments, exit code 137).
```text
$ kubectl apply -f 08-liveness.yaml
pod/lifecycle-liveness created
$ kubectl get pod lifecycle-liveness   (after 5s)
NAME                 READY   STATUS    RESTARTS   AGE
lifecycle-liveness   1/1     Running   0          5s
$ kubectl get pod lifecycle-liveness   (after 60s)
NAME                 READY   STATUS    RESTARTS   AGE
lifecycle-liveness   1/1     Running   0          60s
Status: Running
State: Running
Ready: True
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 60s default-scheduler Successfully assigned s10/lifecycle-liveness to minikube
Normal Pulled 60s kubelet spec.containers{app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
Normal Created 60s kubelet spec.containers{app}: Container created
Normal Started 60s kubelet spec.containers{app}: Container started
Warning Unhealthy 30s (x2 over 35s) kubelet spec.containers{app}: Liveness probe failed:
Normal Killing 30s kubelet spec.containers{app}: Container app failed liveness probe, will be restarted
```

### 09 STARTUP
**Observation:** Startup probe fails (`Startup probe failed`) while the slow app boots (30 s); the Pod becomes Ready only after the probe succeeds, and liveness checks are held off until then.
```text
$ kubectl apply -f 09-startup.yaml
pod/lifecycle-startup created
$ kubectl get pod lifecycle-startup   (after 8s)
NAME                READY   STATUS    RESTARTS   AGE
lifecycle-startup   0/1     Running   0          8s
$ kubectl get pod lifecycle-startup   (after 48s)
NAME                READY   STATUS    RESTARTS   AGE
lifecycle-startup   1/1     Running   0          49s
Status: Running
State: Running
Ready: True
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 48s default-scheduler Successfully assigned s10/lifecycle-startup to minikube
Normal Pulled 48s kubelet spec.containers{slow-app}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
Normal Created 48s kubelet spec.containers{slow-app}: Container created
Normal Started 48s kubelet spec.containers{slow-app}: Container started
Warning Unhealthy 18s (x6 over 43s) kubelet spec.containers{slow-app}: Startup probe failed:
```

### 10 INIT CONTAINER
**Observation:** `Init:0/1` – the init container runs first and must finish; only then the main container starts.
```text
$ kubectl apply -f 10-init-container.yaml
pod/lifecycle-init created
$ kubectl get pod lifecycle-init   (after 4s)
NAME             READY   STATUS     RESTARTS   AGE
lifecycle-init   0/1     Init:0/1   0          4s
$ kubectl get pod lifecycle-init   (after 18s)
NAME             READY   STATUS    RESTARTS   AGE
lifecycle-init   1/1     Running   0          18s
Status: Running
Init Containers:
State: Terminated
Ready: True
Restart Count: 0
State: Running
Ready: True
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 18s default-scheduler Successfully assigned s10/lifecycle-init to minikube
Normal Pulled 18s kubelet spec.initContainers{setup}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
Normal Created 18s kubelet spec.initContainers{setup}: Container created
Normal Started 18s kubelet spec.initContainers{setup}: Container started
Normal Pulled 7s kubelet spec.containers{app}: Container image "nginx:1.27" already present on machine and can be accessed by the pod
Normal Created 7s kubelet spec.containers{app}: Container created
Normal Started 7s kubelet spec.containers{app}: Container started
```

### 11 MULTI-CONTAINER
**Observation:** `2/2` – app + sidecar containers share the Pod network/lifecycle; logs are read per container.
```text
$ kubectl apply -f 11-multi-container.yaml
pod/lifecycle-multi-container created
$ kubectl get pod lifecycle-multi-container   (after ready)
NAME                        READY   STATUS    RESTARTS   AGE
lifecycle-multi-container   2/2     Running   0          0s
$ kubectl logs lifecycle-multi-container -c <sidecar>
2026/10/07 17:03:26 [notice] 1#1: start worker process 38
2026/10/07 17:03:26 [notice] 1#1: start worker process 39
Sidecar is running
Status: Running
State: Running
Ready: True
Restart Count: 0
State: Running
Ready: True
Restart Count: 0
Type Status
Type Reason Age From Message
Normal Scheduled 0s default-scheduler Successfully assigned s10/lifecycle-multi-container to minikube
Normal Pulled 1s kubelet spec.containers{app}: Container image "nginx:1.27" already present on machine and can be accessed by the pod
Normal Created 1s kubelet spec.containers{app}: Container created
Normal Started 1s kubelet spec.containers{app}: Container started
Normal Pulled 1s kubelet spec.containers{sidecar}: Container image "busybox:1.36" already present on machine and can be accessed by the pod
Normal Created 1s kubelet spec.containers{sidecar}: Container created
Normal Started 1s kubelet spec.containers{sidecar}: Container started
```

### 12 TERMINATION
**Observation:** On delete the Pod goes `Terminating`; SIGTERM is sent, the container gets `terminationGracePeriodSeconds` (20 s) to exit, then SIGKILL.
```text
$ kubectl apply -f 12-termination.yaml
pod/lifecycle-termination created
$ kubectl get pod lifecycle-termination   (after ready)
NAME                    READY   STATUS    RESTARTS   AGE
lifecycle-termination   1/1     Running   0          0s
$ kubectl delete pod lifecycle-termination --wait=false; kubectl get pod lifecycle-termination -w
pod "lifecycle-termination" deleted from s10 namespace
lifecycle-termination   1/1   Terminating   0     0s
lifecycle-termination   1/1   Terminating   0     5s
lifecycle-termination   1/1   Terminating   0     9s
Error from server (NotFound): pods "lifecycle-termination" not found
(after grace period)
Error from server (NotFound): pods "lifecycle-termination" not found
```

### Extra capture: crash-loop restarts and liveness restart (polled until the state occurred)
```text
$ kubectl apply -f 05-crashloopbackoff.yaml
pod/lifecycle-crashloop created
$ kubectl get pod lifecycle-crashloop   (CrashLoopBackOff reached)
NAME                  READY   STATUS   RESTARTS      AGE
lifecycle-crashloop   0/1     Error    4 (73s ago)   2m5s
$ kubectl describe pod lifecycle-crashloop   (key fields)
Status: Running
 State: Terminated
 Reason: Error
 Exit Code: 1
 Last State: Terminated
 Reason: Error
 Exit Code: 1
 Restart Count: 4
 Warning BackOff 18s (x4 over 116s) kubelet spec.containers{crashing-app}: Back-off restarting failed container crashing-app in pod lifecycl
$ kubectl logs lifecycle-crashloop --previous
unable to retrieve container logs for containerd://577e8ab67d0d1b69c4fa456023c596dfb4061769976e545c0a36ccc32d05022e
$ kubectl apply -f 08-liveness.yaml
pod/lifecycle-liveness created
$ kubectl get pod lifecycle-liveness   (after liveness probe failure)
NAME                 READY   STATUS    RESTARTS     AGE
lifecycle-liveness   1/1     Running   1 (2s ago)   62s
$ kubectl describe pod lifecycle-liveness   (key fields)
 Last State: Terminated
 Reason: Error
 Exit Code: 137
 Restart Count: 1
 Type Reason Age From Message
 Warning Unhealthy 32s (x2 over 37s) kubelet spec.containers{app}: Liveness probe failed:
 Normal Killing 32s kubelet spec.containers{app}: Container app failed liveness probe, will be restarted
```

### Final overview of all Pods
```text
$ kubectl get pods
NAME                        READY   STATUS             RESTARTS       AGE
lifecycle-crashloop         0/1     Error              5 (2m7s ago)   4m2s
lifecycle-failed            0/1     Error              0              4m17s
lifecycle-image-error       0/1     ImagePullBackOff   0              3m12s
lifecycle-init              1/1     Running            0              48s
lifecycle-liveness          1/1     Running            2 (37s ago)    2m37s
lifecycle-multi-container   2/2     Running            0              30s
lifecycle-pending           0/1     Pending            0              4m39s
lifecycle-readiness         1/1     Running            0              2m52s
lifecycle-running           1/1     Running            0              4m39s
lifecycle-startup           1/1     Running            0              97s
lifecycle-succeeded         0/1     Completed          0              4m33s
```

## Pod phases summary
| Phase / state | Meaning |
|---|---|
| Pending | accepted but not running (unschedulable, pulling image, init containers) |
| Running | at least one container running |
| Succeeded | all containers exited 0 (restartPolicy Never/OnFailure) |
| Failed | a container exited non-zero (restartPolicy Never) |
| CrashLoopBackOff | container keeps crashing; kubelet delays restarts exponentially (10 s → 5 min) |
| ErrImagePull / ImagePullBackOff | image cannot be pulled |
| Init:N/M | init containers still running |
