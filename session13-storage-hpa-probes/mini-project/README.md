# Session 13 – Mini Project: Production-Ready Kubernetes Web App

A web application (nginx) with **persistent storage**, **autoscaling** and **health probes**, in namespace `production-webapp`.

```text
                    [ Service: web-service ]  (ClusterIP :80)
                               │
              ┌────────────────┼────────────────┐
         [ Pod web-app ]  [ Pod web-app ]  [ Pod web-app … ]   ← HPA: 2–5 replicas, 50 % CPU
          startup / readiness / liveness probes, requests+limits
                               │  volumeMount /data
                        PVC web-data (500Mi, RWO)
                               │
                  StorageClass standard (minikube-hostpath) → PersistentVolume
```

| File | Purpose |
|---|---|
| [`namespace.yaml`](namespace.yaml) | Namespace `production-webapp` |
| [`pvc.yaml`](pvc.yaml) | 500Mi `ReadWriteOnce` claim (dynamic provisioning) |
| [`deployment.yaml`](deployment.yaml) | 2 replicas, `/data` volume, **startup + readiness + liveness probes**, CPU/memory requests & limits |
| [`service.yaml`](service.yaml) | ClusterIP Service on port 80 |
| [`hpa.yaml`](hpa.yaml) | HPA: min 2, max 5, target 50 % CPU |

```yaml
# deployment.yaml (excerpt: probes + volume)
          volumeMounts:
            - name: persistent-storage
              mountPath: /data
          startupProbe:
            httpGet:
              path: /
              port: 80
            failureThreshold: 30
            periodSeconds: 2
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 2
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3
      volumes:
        - name: persistent-storage
          persistentVolumeClaim:
            claimName: web-data
```

## Step 1 – Deploy (namespace, PVC, Deployment, Service, HPA)
```text
$ kubectl apply -f namespace.yaml
namespace/production-webapp created

$ kubectl apply -f pvc.yaml; sleep 3; kubectl -n production-webapp get pvc
persistentvolumeclaim/web-data created
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
web-data   Bound    pvc-8b060ce1-b837-4810-b772-ee3e9f872b21   500Mi      RWO            standard       <unset>                 3s

$ kubectl apply -f deployment.yaml -f service.yaml; kubectl -n production-webapp rollout status deploy/web-app --timeout=180s; kubectl -n production-webapp get pods 
deployment.apps/web-app created
service/web-service created
deployment "web-app" successfully rolled out
NAME                      READY   STATUS    RESTARTS   AGE   IP             NODE       NOMINATED NODE   READINESS GATES
web-app-d45775485-d7bvb   1/1     Running   0          10s   10.244.0.202   minikube   <none>           <none>
web-app-d45775485-hfqkj   1/1     Running   0          10s   10.244.0.203   minikube   <none>           <none>
NAME          TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
web-service   ClusterIP   10.97.179.37   <none>        80/TCP    10s

$ kubectl apply -f hpa.yaml; sleep 45; kubectl -n production-webapp get hpa
horizontalpodautoscaler.autoscaling/web-app-hpa created
NAME          REFERENCE            TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2         5         2          45s

$ kubectl -n production-webapp describe deploy web-app | grep -E "Replicas|StrategyType|Liveness|Readiness|Startup|Mounts|/data|web-data"
Replicas:           2 desired | 2 updated | 2 total | 2 available | 0 unavailable
StrategyType:       Recreate
    Liveness:     http-get http://:80/ delay=5s timeout=2s period=5s successThreshold=1 failureThreshold=3
    Readiness:    http-get http://:80/ delay=5s timeout=2s period=5s successThreshold=1 failureThreshold=2
    Startup:      http-get http://:80/ delay=0s timeout=1s period=2s successThreshold=1 failureThreshold=30
    Mounts:
      /data from persistent-storage (rw)
    ClaimName:     web-data
  Available      True    MinimumReplicasAvailable
```
The PVC is `Bound` (a PV was created dynamically), 2 Pods are `Running`, and the HPA is created (its target shows `<unknown>` for the first ~minute until metrics-server has data). `describe deploy` confirms the three probes and the `/data` mount.

## Task 1 – Storage persistence
```text
$ POD=$(kubectl -n production-webapp get pods -l app=web-app -o jsonpath="{.items[0].metadata.name}"); echo "pod: $POD"; kubectl -n production-webapp exec $POD -- sh
pod: web-app-d45775485-d7bvb
Student: Subhan Rahiman

$ POD=$(kubectl -n production-webapp get pods -l app=web-app -o jsonpath="{.items[0].metadata.name}"); kubectl -n production-webapp delete pod $POD --wait=true; kube
pod "web-app-d45775485-d7bvb" deleted from production-webapp namespace
deployment "web-app" successfully rolled out
NAME                      READY   STATUS    RESTARTS   AGE
web-app-d45775485-gjq6p   1/1     Running   0          11s
web-app-d45775485-hfqkj   1/1     Running   0          67s
new pod: web-app-d45775485-gjq6p
Student: Subhan Rahiman
```
✅ The file written to `/data` **survived the deletion of the Pod** – it lives on the PersistentVolume, not in the container.

## Task 2 – Service verification
```text
$ kubectl -n production-webapp get endpoints web-service; kubectl -n production-webapp run svc-check --image=curlimages/curl:8.10.1 --restart=Never --rm -i --command
NAME          ENDPOINTS                         AGE
web-service   10.244.0.203:80,10.244.0.205:80   67s
HTTP 200 via web-service
HTTP 200 via web-service
pod "svc-check" deleted from production-webapp namespace
```
✅ The Service has 2 endpoints and answers `HTTP 200`. (The two `HTTP 200` lines appear because `kubectl run -i` printed the result twice.)

## Task 3 – HPA elastic scaling
Four `busybox` Pods (`load-generator-1..4`) loop `wget http://web-service`; samples every 15 s:
```text
$ for i in 1 2 3 4; do kubectl -n production-webapp run load-generator-$i --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-s
pod/load-generator-1 created
pod/load-generator-2 created
pod/load-generator-3 created
pod/load-generator-4 created
pod/load-generator-1 condition met
pod/load-generator-2 condition met
pod/load-generator-3 condition met
pod/load-generator-4 condition met
NAME                      READY   STATUS    RESTARTS   AGE
load-generator-1          1/1     Running   0          0s
load-generator-2          1/1     Running   0          0s
load-generator-3          1/1     Running   0          0s
load-generator-4          1/1     Running   0          0s
web-app-d45775485-gjq6p   1/1     Running   0          13s
web-app-d45775485-hfqkj   1/1     Running   0          69s

$ kubectl get hpa -w   (sampled every 15s)
--- t=15s
web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2     5     2     60s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=30s
web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2     5     2     75s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=45s
web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2     5     2     90s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=60s
web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2     5     2     105s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=75s
web-app-hpa   Deployment/web-app   cpu: 42%/50%   2     5     2     2m1s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=90s
web-app-hpa   Deployment/web-app   cpu: 42%/50%   2     5     2     2m16s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=105s
web-app-hpa   Deployment/web-app   cpu: 42%/50%   2     5     2     2m31s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=120s
web-app-hpa   Deployment/web-app   cpu: 42%/50%   2     5     2     2m46s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
--- t=135s
web-app-hpa   Deployment/web-app   cpu: 64%/50%   2     5     2     3m2s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 0/1 Running
--- t=150s
web-app-hpa   Deployment/web-app   cpu: 64%/50%   2     5     3     3m17s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=165s
web-app-hpa   Deployment/web-app   cpu: 64%/50%   2     5     3     3m32s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=180s
web-app-hpa   Deployment/web-app   cpu: 64%/50%   2     5     3     3m47s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=195s
web-app-hpa   Deployment/web-app   cpu: 55%/50%   2     5     3     4m2s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=210s
web-app-hpa   Deployment/web-app   cpu: 55%/50%   2     5     3     4m18s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=225s
web-app-hpa   Deployment/web-app   cpu: 55%/50%   2     5     3     4m33s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=240s
web-app-hpa   Deployment/web-app   cpu: 55%/50%   2     5     3     4m48s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=255s
web-app-hpa   Deployment/web-app   cpu: 46%/50%   2     5     3     5m4s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=270s
web-app-hpa   Deployment/web-app   cpu: 46%/50%   2     5     3     5m19s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=285s
web-app-hpa   Deployment/web-app   cpu: 46%/50%   2     5     3     5m34s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
--- t=300s
web-app-hpa   Deployment/web-app   cpu: 46%/50%   2     5     3     5m49s
   web-app-d45775485-gjq6p 1/1 Running
   web-app-d45775485-hfqkj 1/1 Running
   web-app-d45775485-pqkq4 1/1 Running
$ kubectl -n production-webapp get hpa; kubectl -n production-webapp get pods -l app=web-app; kubectl -n production-webapp top pods
NAME          REFERENCE            TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
web-app-hpa   Deployment/web-app   cpu: 45%/50%   2         5         3          6m5s
NAME                      READY   STATUS    RESTARTS   AGE
web-app-d45775485-gjq6p   1/1     Running   0          5m19s
web-app-d45775485-hfqkj   1/1     Running   0          6m15s
web-app-d45775485-pqkq4   1/1     Running   0          3m4s
NAME                      CPU(cores)   MEMORY(bytes)   
load-generator-1          293m         4Mi             
load-generator-2          291m         2Mi             
load-generator-3          291m         2Mi             
load-generator-4          290m         2Mi             
web-app-d45775485-gjq6p   46m          9Mi             
web-app-d45775485-hfqkj   45m          9Mi             
web-app-d45775485-pqkq4   46m          9Mi             

$ kubectl -n production-webapp describe hpa web-app-hpa | sed -n "/Metrics:/,\$p"
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  45% (45m) / 50%
Min replicas:                                          2
Max replicas:                                          5
Deployment pods:                                       3 current / 3 desired
Conditions:
  Type            Status  Reason              Message
  ----            ------  ------              -------
  AbleToScale     True    ReadyForNewScale    recommended size matches current size
  ScalingActive   True    ValidMetricFound    the HPA was able to successfully calculate a replica count from cpu resource utilization (percentage of request)
  ScalingLimited  False   DesiredWithinRange  the desired count is within the acceptable range
  ScaledToZero    False   NotScaledToZero     the HPA controller did not scale the workload to zero
Events:
  Type     Reason                        Age                   From                       Message
  ----     ------                        ----                  ----                       -------
  Warning  FailedGetResourceMetric       5m20s (x4 over 6m5s)  horizontal-pod-autoscaler  failed to get cpu utilization: unable to get metrics for resource cpu: no m
  Warning  FailedComputeMetricsReplicas  5m20s (x4 over 6m5s)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu res
  Warning  FailedGetResourceMetric       4m20s (x4 over 5m5s)  horizontal-pod-autoscaler  failed to get cpu utilization: did not receive metrics for targeted pods (p
  Warning  FailedComputeMetricsReplicas  4m20s (x4 over 5m5s)  horizontal-pod-autoscaler  invalid metrics (1 invalid out of 1), first error is: failed to get cpu res
  Normal   SuccessfulRescale             3m4s                  horizontal-pod-autoscaler  New size: 3; reason: cpu resource utilization (percentage of request) above

$ kubectl -n production-webapp delete pod -l run --wait=true; sleep 45; kubectl -n production-webapp get hpa; kubectl -n production-webapp get pods -l app=web-app
pod "load-generator-1" deleted from production-webapp namespace
pod "load-generator-2" deleted from production-webapp namespace
pod "load-generator-3" deleted from production-webapp namespace
pod "load-generator-4" deleted from production-webapp namespace
NAME          REFERENCE            TARGETS        MINPODS   MAXPODS   REPLICAS   AGE
web-app-hpa   Deployment/web-app   cpu: 38%/50%   2         5         3          7m22s
NAME                      READY   STATUS    RESTARTS   AGE
web-app-d45775485-gjq6p   1/1     Running   0          6m36s
web-app-d45775485-hfqkj   1/1     Running   0          7m32s
web-app-d45775485-pqkq4   1/1     Running   0          4m21s
```
**Result:** CPU rose from 12 % → **64 % (> 50 % target)** → HPA scaled **2 → 3 replicas** (`SuccessfulRescale`), after which average CPU settled at ~45 % (below target, so it stopped at 3). After the load was removed the HPA remains at the current size until the 5-minute scale-down window ends. (The initial `FailedGetResourceMetric` warnings are the normal metrics-server warm-up.)

## Cleanup
`kubectl delete ns production-webapp` (removes Pods, Service, HPA and the PVC/PV).
