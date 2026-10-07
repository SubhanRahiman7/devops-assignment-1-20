# Observability (Session 20 – Task 2)

## Monitoring vs observability
| | Monitoring | Observability |
|---|---|---|
| Question | "**Is** something wrong?" | "**Why** is it wrong, even for a problem I did not predict?" |
| Approach | predefined dashboards and alerts for known failure modes | exploring rich telemetry (metrics + logs + traces) to debug unknown problems |
| Example | alert: CPU > 80 % | follow one slow request across 6 microservices and see which database call took 3 s |

Observability is the ability to understand the **internal state** of a system from the data it emits. Monitoring is one use of that data.

## The three pillars
### 1. Metrics – *what is happening (numbers over time)*
* Numeric measurements sampled at intervals and stored as **time series**: CPU %, memory, request rate, error rate, latency percentiles, queue length.
* Cheap to store, good for **dashboards and alerts**, trends and capacity planning, but little detail about *individual* events.
* Types: counter (only goes up – requests), gauge (up/down – memory), histogram (latency buckets).
* The **golden signals**: latency, traffic, errors, saturation (RED method for services: Rate, Errors, Duration; USE for resources: Utilisation, Saturation, Errors).
* Tools: **Prometheus**, Graphite, InfluxDB, CloudWatch, Datadog. Visualisation: **Grafana**.

### 2. Logs – *what exactly happened (events with detail)*
* Timestamped text/JSON records of discrete events: errors, stack traces, audit trail, access logs.
* Highest detail, essential for root cause, but large volumes → use structured (JSON) logs, levels, correlation/trace IDs, retention policies.
* Tools: **Loki** (+ Promtail), **ELK/EFK** (Elasticsearch, Logstash/Fluentd/Fluent Bit, Kibana), Splunk, CloudWatch Logs, `kubectl logs`.

### 3. Traces – *where did the time go (a request's journey)*
* A **trace** follows one request through all services; it consists of **spans** (one per operation/call) with start time, duration, parent span, tags. Propagated with a trace-ID header (W3C `traceparent`).
* Reveals latency bottlenecks and dependency problems in microservices that metrics/logs cannot show.
* Tools: **OpenTelemetry** (instrumentation standard), **Jaeger**, **Grafana Tempo**, Zipkin, AWS X-Ray, Datadog APM.

```text
Metrics: "error rate rose to 5 % at 10:02"                    (detect)
Traces : "checkout → payment-service spans 2.8 s in the DB"    (locate)
Logs   : "payment-service: connection pool exhausted (max 10)" (explain)
```

## Why observability is required
* **Distributed systems** (microservices, containers, Kubernetes) fail in complex, unpredictable ways – you cannot SSH into a short-lived Pod after it is gone.
* Reduce **MTTD / MTTR** (mean time to detect / repair) and protect SLAs/SLOs (error budgets).
* Find **performance bottlenecks** and capacity needs; understand real user impact.
* Enables safe, fast delivery (verify each deployment with canary/rollback decisions based on data) and supports **incident postmortems**.
* Security and audit (who did what, when).

## Common tools
| Purpose | Open source | Commercial / cloud |
|---|---|---|
| Metrics | Prometheus, VictoriaMetrics, Thanos/Mimir | Datadog, New Relic, CloudWatch |
| Dashboards | **Grafana** | Datadog, Dynatrace |
| Logs | Loki, ELK/EFK, Fluent Bit/Fluentd, Vector | Splunk, CloudWatch Logs, Datadog |
| Traces | Jaeger, Tempo, Zipkin | X-Ray, Datadog APM, Honeycomb |
| Instrumentation | **OpenTelemetry** (metrics + logs + traces, vendor-neutral) | – |
| Alerting | Alertmanager, Grafana Alerting | PagerDuty, Opsgenie |

## Kubernetes observability
| Layer | What / how |
|---|---|
| **Built-in quick checks** | `kubectl get/describe/logs/exec/events`, `kubectl top` (needs **metrics-server**) |
| **Cluster & node metrics** | **kubelet/cAdvisor** (container CPU/memory), **node-exporter** (node), **kube-state-metrics** (state of Deployments/Pods/HPA: replicas, restarts, phase), API-server and etcd metrics |
| **Metrics stack** | **Prometheus Operator / kube-prometheus-stack** (Helm): Prometheus + Alertmanager + Grafana + ready-made dashboards; `ServiceMonitor`/`PodMonitor` CRDs tell Prometheus what to scrape; pod annotations `prometheus.io/scrape` |
| **Logs** | containers write to stdout/stderr → node log files → **Fluent Bit / Promtail** DaemonSet → **Loki / Elasticsearch**; query with LogQL/Kibana |
| **Traces** | apps instrumented with OpenTelemetry SDK → **OTel Collector** → Tempo / Jaeger; service meshes (Istio/Linkerd) add traces and golden-signal metrics automatically |
| **Events** | `kubectl get events`, exported with event-exporter |
| **Probes** | liveness / readiness / startup probes expose app health to the kubelet |
| **Alerts** | PrometheusRule CRDs, e.g. `KubePodCrashLooping`, `KubeDeploymentReplicasMismatch`, node `NotReady`, `CPUThrottlingHigh` |
| **Autoscaling link** | HPA consumes metrics (CPU/memory/custom) – observability drives automation |

### Typical alerts for a Kubernetes cluster
`KubePodCrashLooping` · `KubePodNotReady` · `KubeDeploymentReplicasMismatch` · `NodeNotReady` · `NodeMemoryHighUtilisation` · `PersistentVolumeFillingUp` · `ContainerOOMKilled` · `HighErrorRate` · `HighLatencyP99`.

Practical demo of the metrics + logs + alerts parts: [`../monitoring-demo`](../monitoring-demo/README.md).
