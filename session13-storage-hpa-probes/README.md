# Session 13 – Kubernetes Storage, HPA & Probes

| Task | Folder / README |
|---|---|
| Task 1 – Kubernetes Volumes (emptyDir, hostPath, PV, PVC, StorageClass, dynamic provisioning) | [`01-kubernetes-volumes/README.md`](01-kubernetes-volumes/README.md) |
| Task 2 – HPA hands-on (deployment, HPA, load generator, scaling, outputs) | [`02-hpa/README.md`](02-hpa/README.md) |
| Task 3 – Mini project (PVC + HPA + probes) | [`mini-project/README.md`](mini-project/README.md) |

## Key results
* **Volumes:** `emptyDir` survives a container restart but not Pod deletion; `hostPath` lives on the node; a **PV/PVC** keeps data after the Pod is deleted; a **StorageClass** creates (and deletes) PVs dynamically.
* **HPA:** CPU 12 % → 86 % under load → scaled **1 → 2** replicas; after the load stopped and the 5-minute stabilisation window it returned to **1**.
* **Mini project:** data persisted across Pod deletion, Service answered `200`, HPA scaled **2 → 3** under load, startup/readiness/liveness probes configured.

## Probes (used in the mini project)
| Probe | Question | On failure |
|---|---|---|
| **startupProbe** | Has the app finished starting? | keeps other probes disabled; restarts container if it never succeeds |
| **readinessProbe** | Can it receive traffic now? | Pod removed from Service endpoints (no restart) |
| **livenessProbe** | Is it still healthy? | container is killed and restarted |
(The Pod-lifecycle demo in Session 10 shows each of them failing and recovering.)

## Notes
* All demos ran in separate namespaces (`s13`, `s13-hpa`, `production-webapp`); the PV used was named `hw-student-pv` so that existing objects in the cluster were not touched.
* The reference PVC had no `storageClassName`, so Minikube's default StorageClass would have provisioned a *new* volume instead of binding the static PV – fixed with `storageClassName: manual` (see the volumes README).
