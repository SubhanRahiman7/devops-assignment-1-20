# DevOps Assignments (Sessions 2 – 20)

One folder per session. Every README contains the commands, the **real outputs**, explanations, and **screenshots** (terminal output images and live browser screenshots).

| Session | Topic | README |
|---|---|---|
| 2 | Linux (links, adduser/useradd, journalctl, cheat sheet) | [session02-linux](session02-linux/README.md) |
| 3 | Shell scripting | [session03-shell-scripting](session03-shell-scripting/README.md) |
| 4 | Networking | [session04-networking](session04-networking/README.md) |
| 5 | Git (`commit -a -m`, cherry-pick) | [session05-git](session05-git/README.md) |
| 6 | Docker Hello World apps (6 apps) | [session06-docker-hello-world](session06-docker-hello-world/README.md) |
| 7 | Docker multi-stage build | [session07-docker-multistage](session07-docker-multistage/README.md) |
| 8 | Docker networking & volumes | [session08-docker-networking-volumes](session08-docker-networking-volumes/README.md) |
| 9 | Kubernetes fundamentals (Minikube) | [session09-kubernetes-minikube](session09-kubernetes-minikube/README.md) |
| 10 | Deployment strategies & Pod lifecycle | [session10-k8s-deployments-lifecycle](session10-k8s-deployments-lifecycle/README.md) |
| 11 | Services, comparison docs, FQDN, CoreDNS | [session11-k8s-services](session11-k8s-services/README.md) · [object comparison](session11-k8s-services/object-comparison/README.md) · [fqdn](session11-k8s-services/fqdn/README.md) · [coredns](session11-k8s-services/coredns/README.md) |
| 12 | Ingress, ConfigMaps & Secrets | [session12-ingress-configmap-secret](session12-ingress-configmap-secret/README.md) |
| 13 | Storage, HPA & probes | [session13-storage-hpa-probes](session13-storage-hpa-probes/README.md) · [volumes](session13-storage-hpa-probes/01-kubernetes-volumes/README.md) · [HPA](session13-storage-hpa-probes/02-hpa/README.md) · [mini project](session13-storage-hpa-probes/mini-project/README.md) |
| 14 | Kubernetes troubleshooting | [session14-k8s-troubleshooting](session14-k8s-troubleshooting/README.md) |
| 15 | Helm | [session15-helm](session15-helm/README.md) · [commands](session15-helm/01-helm-commands/README.md) · [rollback](session15-helm/02-helm-rollback/README.md) · [mini project](session15-helm/mini-project/README.md) |
| 16 | CI/CD with GitHub Actions | [session16-cicd-github-actions](session16-cicd-github-actions/README.md) |
| 17 | CI/CD + DevSecOps | [session17-devsecops-pipeline](session17-devsecops-pipeline/README.md) |
| 18 | Terraform & IaC (S3 demo + AWS services) | [session18-terraform-iac](session18-terraform-iac/README.md) · [S3 demo](session18-terraform-iac/terraform-s3-demo/README.md) |
| 19 | Terraform end-to-end infrastructure | [session19-terraform-cloud-infrastructure](session19-terraform-cloud-infrastructure/README.md) |
| 20 | Monitoring, Observability & GitOps | [session20-monitoring-observability-gitops](session20-monitoring-observability-gitops/README.md) |

GitHub Actions workflows live in [`.github/workflows/`](.github/workflows/): Session 16 (CI/CD) and Session 17 (DevSecOps).

> **Note on Sessions 18–19:** the Terraform workflows were executed against a local AWS emulator (Moto) because no AWS account/credentials were available; the READMEs state this clearly. The code targets real AWS by default.
