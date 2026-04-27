# Incident Report — High Error Rate (Option A)

| Field | Value |
|---|---|
| **Incident ID** | INC-2024-001 |
| **Severity** | P2 — High |
| **Status** | Resolved |
| **Namespace** | `dev` |
| **Workload** | `sample-app` (Deployment, 2 replicas) |
| **Detection time** | 14:03 UTC |
| **Resolution time** | 14:41 UTC |
| **Total duration** | 38 minutes |
| **Author** | On-call engineer |

---

## 1. Summary

A misconfigured environment variable caused one of two `sample-app` replicas to begin returning HTTP 500 on all requests. The error rate climbed to ~50% (one replica healthy, one returning 100% errors). Prometheus fired `HighErrorRate` after 2 minutes of the threshold breach. The issue was diagnosed via Grafana, confirmed with `kubectl exec` curl tests, root-caused to a bad ConfigMap update, and resolved by rolling back the ConfigMap and triggering a rolling restart.

---

## 2. Incident Timeline

```
14:01 UTC  Engineer applies updated ConfigMap with a typo in DATABASE_URL.
           Rolling restart begins — one pod picks up the bad config.

14:02 UTC  New pod starts returning HTTP 500 on all requests.
           Error rate climbs to ~48% (1 of 2 replicas broken).

14:03 UTC  Prometheus evaluates HighErrorRate rule.
           5xx rate / total rate = 0.48 → threshold 0.05 breached.

14:05 UTC  [2-minute for: window satisfied]
           Alert fires → PagerDuty → on-call engineer paged.

14:08 UTC  Engineer opens Grafana → "App Metrics + Pod Resources — dev"
           dashboard. Request Rate panel shows 5xx bar rising sharply.
           Error Rate panel shows flat red line at ~48%.

14:11 UTC  Engineer checks Latency panel.
           p99 has spiked to 4.2s (upstream DB connection timeout on 500s).

14:13 UTC  kubectl investigation begins (see Section 3).

14:19 UTC  Root cause identified: DATABASE_URL typo in ConfigMap.

14:22 UTC  Fix applied: ConfigMap corrected, rolling restart triggered.

14:25 UTC  First healthy replacement pod reaches Running/Ready.
           Error rate drops to ~24% (1 broken pod still draining).

14:28 UTC  Second replacement pod ready. Old broken pod terminated.
           Error rate drops to 0%.

14:30 UTC  Prometheus evaluates — HighErrorRate condition no longer met.
           Alert resolves after 2-minute evaluation window.

14:32 UTC  Alert resolution notification sent.

14:41 UTC  Incident declared resolved after 10-minute quiet period.
```

---

## 3. Detection — Grafana Observations

### Panel: Request Rate by Status Code
```
Time     2xx req/s    5xx req/s
──────── ──────────   ─────────
14:00    42.1         0.0
14:02    41.8         39.3        ← spike
14:05    40.9         40.1        ← ~50/50 split
14:10    41.2         40.8
14:22    41.0         40.5        ← fix applied
14:25    41.3         20.1        ← first replacement pod up
14:28    42.4         0.0         ← fully resolved
```

### Panel: HTTP Error Rate (5xx %)
- Baseline: `0.0%`
- Peak: `48.6%` at 14:10 UTC
- Post-fix: `0.0%` at 14:28 UTC
- Threshold line (5%) visually crossed and sustained, matching alert fire

### Panel: Request Latency — p99
- Baseline: `42ms`
- Peak: `4.2s` at 14:12 UTC (DB connection timeout on broken pod propagating to p99)
- Post-fix: returned to `44ms`

### Panel: Pod CPU Usage
- `sample-app-7d4f8-abc12`: normal CPU throughout (healthy pod)
- `sample-app-7d4f8-xz991`: CPU *lower* than baseline (returning 500 immediately, not hitting DB)
- This asymmetry was a secondary signal pointing to one pod being broken, not both

### Panel: Pod Restarts
- `sample-app-7d4f8-xz991`: 0 restarts — the container was UP but returning errors
- Important: absence of restarts ruled out OOMKill and crash loop as root causes

---

## 4. kubectl Investigation Commands

### Step 1 — Check pod status

```bash
kubectl get pods -n dev
```

```
NAME                         READY   STATUS    RESTARTS   AGE
sample-app-7d4f8-abc12       1/1     Running   0          2d
sample-app-7d4f8-xz991       1/1     Running   0          8m
```

Both pods show `Running` and `Ready 1/1`. No crash loop. The problem is application-level, not infrastructure.

---

### Step 2 — Check recent events

```bash
kubectl get events -n dev --sort-by='.lastTimestamp' | tail -20
```

```
14m    Normal   Scheduled        pod/sample-app-7d4f8-xz991   Successfully assigned dev/sample-app-7d4f8-xz991
13m    Normal   Pulled           pod/sample-app-7d4f8-xz991   Container image already present
13m    Normal   Started          pod/sample-app-7d4f8-xz991   Started container app
15m    Normal   ScalingReplicaSet deployment/sample-app        Scaled up replica set ... to 2
```

A new pod was created ~13 minutes ago following a rollout — matches the ConfigMap update window.

---

### Step 3 — Inspect logs on both pods

```bash
# Healthy pod — logs look normal
kubectl logs -n dev sample-app-7d4f8-abc12 --tail=20
```
```
time="14:14:01" level=info msg="GET /api/users 200 38ms"
time="14:14:02" level=info msg="GET /api/items 200 41ms"
```

```bash
# Broken pod — errors on every request
kubectl logs -n dev sample-app-7d4f8-xz991 --tail=20
```
```
time="14:14:01" level=error msg="GET /api/users 500 4201ms" error="dial tcp: lookup postgres-svc: no such host"
time="14:14:02" level=error msg="GET /api/items 500 4198ms" error="dial tcp: lookup postgres-svc: no such host"
```

DNS lookup failure — the hostname `postgres-svc` cannot be resolved. This points to an incorrect `DATABASE_URL`.

---

### Step 4 — Compare environment variables between pods

```bash
# Healthy pod
kubectl exec -n dev sample-app-7d4f8-abc12 -- env | grep DATABASE_URL
```
```
DATABASE_URL=postgres://user:pass@postgres-svc.dev.svc.cluster.local:5432/appdb
```

```bash
# Broken pod
kubectl exec -n dev sample-app-7d4f8-xz991 -- env | grep DATABASE_URL
```
```
DATABASE_URL=postgres://user:pass@postgre-svc.dev.svc.cluster.local:5432/appdb
                                    ^^^^^^^
                                    typo: missing 's'
```

Root cause confirmed.

---

### Step 5 — Verify with curl from inside the pod

```bash
# Traffic from broken pod to the (correct) postgres service → fails
kubectl exec -n dev sample-app-7d4f8-xz991 -- \
  curl -sv http://postgre-svc.dev.svc.cluster.local:5432 2>&1 | head -5
```
```
* Could not resolve host: postgre-svc.dev.svc.cluster.local
* Closing connection 0
curl: (6) Could not resolve host: postgre-svc.dev.svc.cluster.local
```

```bash
# Correct hostname resolves fine
kubectl exec -n dev sample-app-7d4f8-xz991 -- \
  curl -sv http://postgres-svc.dev.svc.cluster.local:5432 2>&1 | head -5
```
```
* Connected to postgres-svc.dev.svc.cluster.local (10.96.14.22) port 5432
```

---

### Step 6 — Inspect the ConfigMap

```bash
kubectl get configmap sample-app-config -n dev -o yaml | grep DATABASE_URL
```
```
DATABASE_URL: postgres://user:pass@postgre-svc.dev.svc.cluster.local:5432/appdb
                                    ^^^^^^^  ← typo confirmed in source
```

---

## 5. Root Cause

A typo introduced during a manual ConfigMap update changed `postgres-svc` to `postgre-svc` in the `DATABASE_URL` key. The old pod continued running with the cached correct value. The new pod created during the rolling restart picked up the bad ConfigMap. All database-bound requests on the new pod failed with a DNS resolution error, producing HTTP 500 after a 4-second timeout.

**Root cause category:** Human error — manual config change without peer review or staged rollout validation.

---

## 6. Resolution

```bash
# 1. Fix the typo in the ConfigMap
kubectl patch configmap sample-app-config -n dev \
  --type merge \
  -p '{"data":{"DATABASE_URL":"postgres://user:pass@postgres-svc.dev.svc.cluster.local:5432/appdb"}}'

# 2. Trigger a rolling restart to pick up the corrected ConfigMap
kubectl rollout restart deployment/sample-app -n dev

# 3. Monitor the rollout
kubectl rollout status deployment/sample-app -n dev --timeout=120s
```
```
Waiting for deployment "sample-app" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "sample-app" rollout to finish: 1 old replicas are pending termination...
deployment "sample-app" successfully rolled out
```

```bash
# 4. Confirm error rate returned to 0 in Prometheus
kubectl exec -n dev frontend -- \
  curl -s 'http://prometheus.monitoring.svc.cluster.local:9090/api/v1/query' \
  --data-urlencode 'query=sum(rate(http_requests_total{namespace="dev",code=~"5.."}[5m]))'
```
```json
{"status":"success","data":{"resultType":"vector","result":[{"metric":{},"value":[1706191920,"0"]}]}}
```

---

## 7. Metrics Summary

| Metric | Baseline | Peak (incident) | Post-resolution |
|---|---|---|---|
| HTTP error rate (5xx %) | 0.0% | 48.6% | 0.0% |
| Request rate (total req/s) | 42.0 | 81.7 (2xx + 5xx) | 42.4 |
| p99 latency | 42ms | 4,200ms | 44ms |
| Pod restarts | 0 | 0 | 0 |
| CPU usage (broken pod) | ~90m cores | ~15m cores | ~91m cores |

---

## 8. Contributing Factors

| Factor | Description |
|---|---|
| No config validation | The ConfigMap value was not validated against a known-good DNS record before apply |
| Rolling restart surfaced the bug | The old pod masked the problem until it was replaced |
| Missing readiness probe on DB path | The readiness probe checked `/metrics` (always 200), not the DB connection path. A proper readiness probe would have prevented the broken pod from ever entering the load balancer rotation |
| No staging environment | The change was applied directly to `dev` without a pre-deploy validation step |

---

## 9. Action Items

| # | Action | Owner | Priority | Due |
|---|---|---|---|---|
| 1 | Add a database connectivity check to the readiness probe (`/healthz/ready` that tests DB) | App team | High | Sprint +1 |
| 2 | Enforce ConfigMap changes through GitOps (PR + review) — no manual `kubectl patch` | Platform team | High | Sprint +1 |
| 3 | Add `HighErrorRateOnSinglePod` alert (error rate > 80% for any single pod) | Observability | Medium | Sprint +2 |
| 4 | Add a pre-rollout canary step that checks error rate before proceeding (Argo Rollouts or Flagger) | Platform team | Medium | Sprint +3 |
| 5 | Add `DATABASE_URL` format validation to the app startup sequence — fail fast with a clear error | App team | Low | Sprint +2 |
