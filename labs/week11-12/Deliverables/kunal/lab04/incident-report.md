# Lab 04 - Incident Report

## Symptom

Application response latency increased and dashboard request throughput became unstable shortly after scaling a CPU stress workload.

## Metrics Observed

- **Application metrics**: `http_requests_total` rate flattened and became bursty during the incident window.
- **CPU metrics**: `container_cpu_usage_seconds_total` showed sustained elevated CPU usage for `cpu-burner-*` Pods and pressure on the namespace.
- **Memory metrics**: `container_memory_working_set_bytes` remained stable; no OOM pattern observed.

## Timeline

- **T0** - Baseline healthy state (`podinfo` deployment available).
- **T0 + 2m** - Incident introduced by scaling `cpu-burner` deployment to 2 replicas.
- **T0 + 4m** - Grafana panel shows clear CPU rise; request behavior begins degrading.
- **T0 + 8m** - Root cause confirmed as CPU saturation from intentionally introduced stress workload.
- **T0 + 10m** - Mitigation applied: scale `cpu-burner` back to 0 replicas.
- **T0 + 13m** - CPU trend returns to baseline and request rate stabilizes.

## Root Cause

Resource saturation (CPU contention) in the cluster from a stress-test deployment (`cpu-burner`) running compute-intensive workloads.

## Resolution

Immediate:

```bash
kubectl scale deployment/cpu-burner -n observability-lab --replicas=0
```

Preventive:
- Keep stress tooling disabled by default in non-test environments.
- Add alerting on namespace CPU usage and request-rate degradation.
- Enforce tighter resource quotas/limits for ad-hoc test workloads.
