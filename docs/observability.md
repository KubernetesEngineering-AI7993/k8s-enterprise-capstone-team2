# Kubernetes Enterprise Capstone - Observability Model

## Monitoring Scope

The platform targets three observability layers:

- **Workload health**: pod readiness/liveness, restart trends
- **Pipeline throughput**: intake queue depth and inference frame processing
- **Business outcomes**: detected object counts and alert triggers

## Prometheus Integration

- A `ServiceMonitor` is defined for intake, inference, and dashboard services.
- Scrape interval is set to 30 seconds for near-real-time operational feedback.
- Current workloads are placeholders; production services should expose `/metrics`.

## Grafana Dashboards

- Dashboard-as-code is represented as a ConfigMap under `monitoring/grafana`.
- Initial panels are included for:
  - Inference throughput
  - Intake queue backlog
- As real services arrive, add:
  - per-camera latency
  - detection confidence distribution
  - dropped-frame and error rates

## Alerting Priorities (Next Step)

- `cv-inference` unavailable replicas > 0 for 5m
- sustained queue growth (backlog rising while throughput flatlines)
- ingestion service restart burst
- missing metrics from critical workloads

## Incident Readiness

- This design supports week11-12 style incident simulation with:
  - RBAC validation
  - traffic isolation validation via NetworkPolicy
  - HPA behavior checks under synthetic load
