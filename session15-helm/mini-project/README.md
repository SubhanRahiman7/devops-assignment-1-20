# Helm Mini Project – Notes App (Session 15 – Task 3)

An nginx workload represents a "Notes" application packaged as a Helm chart ([`notes-chart/`](notes-chart/)):

```text
notes-chart/
  Chart.yaml          # name, version, appVersion
  values.yaml         # dev defaults:  1 replica, nginx:1.24, ENVIRONMENT=development
  values-prod.yaml    # prod override: 3 replicas, nginx:1.25, ENVIRONMENT=production
  templates/
    deployment.yaml   # {{ .Release.Name }}-deploy, image/replicas from values, envFrom ConfigMap
    service.yaml      # NodePort service
    configmap.yaml    # APP_NAME / ENVIRONMENT from values
```
```yaml
# values.yaml
replicaCount: 1

image:
  repository: nginx
  tag: "1.24"

service:
  port: 80
  nodePort: 30090

app:
  name: notes-app
  environment: development
---
# values-prod.yaml
replicaCount: 3

image:
  repository: nginx
  tag: "1.25"

service:
  port: 80
  nodePort: 30090

app:
  name: notes-app
  environment: production
```

## Install (dev) → Upgrade (prod values) → Rollback
```text
$ helm lint notes-chart; helm template notes-dev notes-chart | grep -E "^kind|replicas|image:|ENVIRONMENT"
==> Linting notes-chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
kind: ConfigMap
  ENVIRONMENT: "development"
kind: Service
kind: Deployment
  replicas: 1
          image: "nginx:1.24"

$ helm install notes-dev notes-chart -n s15; kubectl -n s15 rollout status deploy/notes-dev-deploy --timeout=120s; helm list -n s15; kubectl -n s15 get deploy,svc,cm
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 23:39:49 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None
deployment "notes-dev-deploy" successfully rolled out
NAME     	NAMESPACE	REVISION	UPDATED                             	STATUS  	CHART            	APP VERSION
notes-dev	s15      	1       	2026-10-07 23:39:49.989766 +0530 IST	deployed	notes-chart-0.1.0	1.0        
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/notes-dev-deploy   1/1     1            1           0s

NAME                    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/notes-dev-svc   NodePort   10.109.23.254   <none>        80:30090/TCP   0s

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      3m8s
configmap/notes-dev-config   2      0s

NAME                                    READY   STATUS      RESTARTS   AGE
pod/notes-dev-deploy-74956bd987-7rxlx   1/1     Running     0          0s
pod/rel-app-5d95975d6c-qwvql            0/1     Completed   0          1s
pod/web-demo-chart-test-connection      0/1     Completed   0          2m35s

$ kubectl -n s15 exec deploy/notes-dev-deploy -- env | grep -E "APP_NAME|ENVIRONMENT"; kubectl -n s15 get deploy notes-dev-deploy -o jsonpath="{.spec.template.spec.c
ENVIRONMENT=development
APP_NAME=notes-app
nginx:1.24 replicas=1
HTTP 200 via notes-dev-svc
HTTP 200 via notes-dev-svc
pod "curl-check" deleted from s15 namespace

$ echo "--- UPGRADE to production values"; helm upgrade notes-dev notes-chart -n s15 -f notes-chart/values-prod.yaml; kubectl -n s15 rollout status deploy/notes-dev-
--- UPGRADE to production values
Release "notes-dev" has been upgraded. Happy Helming!
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 23:39:52 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 2
DESCRIPTION: Upgrade complete
TEST SUITE: None
deployment "notes-dev-deploy" successfully rolled out
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/notes-dev-deploy   3/3     3            3           4s

NAME                                    READY   STATUS        RESTARTS   AGE
pod/notes-dev-deploy-74956bd987-7rxlx   1/1     Terminating   0          4s
pod/notes-dev-deploy-bbcc464b4-c7v2m    1/1     Running       0          1s
pod/notes-dev-deploy-bbcc464b4-rl56l    1/1     Running       0          1s
pod/notes-dev-deploy-bbcc464b4-xqxgn    1/1     Running       0          2s
pod/web-demo-chart-test-connection      0/1     Completed     0          2m39s
nginx:1.25
{"APP_NAME":"notes-app","ENVIRONMENT":"production"}
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 23:39:49 2026	superseded	notes-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 23:39:52 2026	deployed  	notes-chart-0.1.0	1.0        	Upgrade complete

$ echo "--- ROLLBACK to revision 1"; helm rollback notes-dev 1 -n s15; kubectl -n s15 rollout status deploy/notes-dev-deploy --timeout=180s; kubectl -n s15 get deplo
--- ROLLBACK to revision 1
Rollback was a success! Happy Helming!
deployment "notes-dev-deploy" successfully rolled out
NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/notes-dev-deploy   1/1     1            1           5s

NAME                                    READY   STATUS        RESTARTS   AGE
pod/notes-dev-deploy-74956bd987-7rxlx   0/1     Completed     0          5s
pod/notes-dev-deploy-74956bd987-vg2wd   1/1     Running       0          1s
pod/notes-dev-deploy-bbcc464b4-c7v2m    1/1     Terminating   0          2s
pod/notes-dev-deploy-bbcc464b4-rl56l    0/1     Completed     0          2s
pod/notes-dev-deploy-bbcc464b4-xqxgn    1/1     Terminating   0          3s
pod/web-demo-chart-test-connection      0/1     Completed     0          2m40s
{"APP_NAME":"notes-app","ENVIRONMENT":"development"}
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION     
1       	Wed Oct  7 23:39:49 2026	superseded	notes-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 23:39:52 2026	superseded	notes-chart-0.1.0	1.0        	Upgrade complete
3       	Wed Oct  7 23:39:54 2026	deployed  	notes-chart-0.1.0	1.0        	Rollback to 1   

$ helm uninstall notes-dev -n s15; kubectl -n s15 get all
release "notes-dev" uninstalled
NAME                                    READY   STATUS        RESTARTS   AGE
pod/notes-dev-deploy-74956bd987-vg2wd   1/1     Terminating   0          1s
pod/notes-dev-deploy-bbcc464b4-c7v2m    0/1     Completed     0          2s
pod/notes-dev-deploy-bbcc464b4-xqxgn    0/1     Completed     0          3s
pod/web-demo-chart-test-connection      0/1     Completed     0          2m40s
```
**Result:**
* `helm install notes-dev notes-chart` → dev release: 1 Pod, `nginx:1.24`, ConfigMap `ENVIRONMENT=development`; Service answered `HTTP 200`.
* `helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml` → **revision 2**: 3 Pods, `nginx:1.25`, `ENVIRONMENT=production` – the **same chart with a different values file** gives a different environment.
* `helm rollback notes-dev 1` → **revision 3** restores the dev configuration; `helm uninstall` removes everything.
