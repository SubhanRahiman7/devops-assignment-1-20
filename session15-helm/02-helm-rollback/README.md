# Helm Rollback Workflow (Session 15 – Task 2)

```
Install → Upgrade → Verify → Upgrade again → Verify → Rollback → Verify
```
Chart: [`app-chart/`](app-chart/) (a Deployment with `image.repository/tag` and `replicaCount` values). Release name `rel`, namespace `s15`.

| Step | Command | Result |
|---|---|---|
| 1 Install | `helm install rel app-chart` | revision **1** – `nginx:1.24`, 1 replica |
| 2 Upgrade | `helm upgrade rel app-chart --set image.tag=1.25 --set replicaCount=2` | revision **2** – `nginx:1.25`, 2 replicas |
| 3 Upgrade again | `helm upgrade rel app-chart --set image.tag=1.27 --set replicaCount=3` | revision **3** – `nginx:1.27`, 3 replicas |
| 4 Rollback | `helm rollback rel 2` | revision **4** ("Rollback to 2") – back to `nginx:1.25`, 2 replicas |

```text
$ cat app-chart/Chart.yaml app-chart/values.yaml; helm lint app-chart
apiVersion: v2
name: app-chart
description: Install and upgrade demo chart
type: application
version: 0.1.0
appVersion: "1.0"
replicaCount: 1

image:
  repository: nginx
  tag: "1.24"
==> Linting app-chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm install rel app-chart -n s15; kubectl -n s15 rollout status deploy/rel-app --timeout=120s; helm list -n s15; kubectl -n s15 get deploy rel-app -o jsonpath="im
NAME: rel
LAST DEPLOYED: Wed Oct  7 23:38:39 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
deployment "rel-app" successfully rolled out
NAME	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART          	APP VERSION
rel 	s15      	1       	2026-10-07 23:38:39.839432 +0530 IST	deployed	app-chart-0.1.0	1.0        
image=nginx:1.24 replicas=1
REVISION	UPDATED                 	STATUS  	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 23:38:39 2026	deployed	app-chart-0.1.0	1.0        	Install complete

$ echo "--- UPGRADE 1: nginx 1.25, 2 replicas"; helm upgrade rel app-chart -n s15 --set image.tag=1.25 --set replicaCount=2; kubectl -n s15 rollout status deploy/rel
--- UPGRADE 1: nginx 1.25, 2 replicas
Release "rel" has been upgraded. Happy Helming!
NAME: rel
LAST DEPLOYED: Wed Oct  7 23:39:28 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 2
DESCRIPTION: Upgrade complete
TEST SUITE: None
deployment "rel-app" successfully rolled out
image=nginx:1.25 replicas=2
NAME                             READY   STATUS        RESTARTS   AGE
rel-app-5d95975d6c-68fjt         1/1     Running       0          0s
rel-app-5d95975d6c-pbbtt         1/1     Running       0          18s
rel-app-66d4754fb8-m4jtz         1/1     Terminating   0          67s
rel-app-66d4754fb8-vdgmg         0/1     Completed     0          18s
web-demo-chart-test-connection   0/1     Completed     0          2m31s
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 23:38:39 2026	superseded	app-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 23:39:28 2026	deployed  	app-chart-0.1.0	1.0        	Upgrade complete

$ echo "--- UPGRADE 2: nginx 1.27, 3 replicas"; helm upgrade rel app-chart -n s15 --set image.tag=1.27 --set replicaCount=3; kubectl -n s15 rollout status deploy/rel
--- UPGRADE 2: nginx 1.27, 3 replicas
Release "rel" has been upgraded. Happy Helming!
NAME: rel
LAST DEPLOYED: Wed Oct  7 23:39:46 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 3
DESCRIPTION: Upgrade complete
TEST SUITE: None
deployment "rel-app" successfully rolled out
image=nginx:1.27 replicas=3
NAME                             READY   STATUS        RESTARTS   AGE
rel-app-5d95975d6c-6w9f7         0/1     Completed     0          2s
rel-app-5d95975d6c-pbbtt         1/1     Terminating   0          20s
rel-app-6b48fcb997-2v7nl         1/1     Running       0          1s
rel-app-6b48fcb997-bcwk4         1/1     Running       0          1s
rel-app-6b48fcb997-st84z         1/1     Running       0          2s
web-demo-chart-test-connection   0/1     Completed     0          2m33s
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 23:38:39 2026	superseded	app-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 23:39:28 2026	superseded	app-chart-0.1.0	1.0        	Upgrade complete
3       	Wed Oct  7 23:39:46 2026	deployed  	app-chart-0.1.0	1.0        	Upgrade complete

$ echo "--- ROLLBACK to revision 2 (nginx 1.25, 2 replicas)"; helm rollback rel 2 -n s15; kubectl -n s15 rollout status deploy/rel-app --timeout=180s; kubectl -n s15
--- ROLLBACK to revision 2 (nginx 1.25, 2 replicas)
Rollback was a success! Happy Helming!
deployment "rel-app" successfully rolled out
image=nginx:1.25 replicas=2
NAME                             READY   STATUS        RESTARTS   AGE
rel-app-5d95975d6c-98k9c         1/1     Running       0          1s
rel-app-5d95975d6c-qwvql         1/1     Running       0          0s
rel-app-6b48fcb997-2v7nl         0/1     Completed     0          2s
rel-app-6b48fcb997-bcwk4         0/1     Completed     0          2s
rel-app-6b48fcb997-st84z         1/1     Terminating   0          3s
web-demo-chart-test-connection   0/1     Completed     0          2m34s
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 23:38:39 2026	superseded	app-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 23:39:28 2026	superseded	app-chart-0.1.0	1.0        	Upgrade complete
3       	Wed Oct  7 23:39:46 2026	superseded	app-chart-0.1.0	1.0        	Upgrade complete
4       	Wed Oct  7 23:39:48 2026	deployed  	app-chart-0.1.0	1.0        	Rollback to 2   
USER-SUPPLIED VALUES:
image:
  tag: "1.25"
replicaCount: 2

$ helm status rel -n s15 | head -n 8; helm uninstall rel -n s15
NAME: rel
LAST DEPLOYED: Wed Oct  7 23:39:48 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 4
DESCRIPTION: Rollback to 2
RESOURCES:
==> v1/Deployment
release "rel" uninstalled
```
**Verified after every step** with `helm history`, `kubectl get deploy -o jsonpath` (image + replicas) and `kubectl get pods`: after the rollback the Deployment runs `nginx:1.25` with 2 replicas again, and the history shows a *new* revision 4 whose description is `Rollback to 2`.
