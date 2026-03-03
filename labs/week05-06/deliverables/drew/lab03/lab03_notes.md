# Lab 03 — Liveness & Readiness Probes

## Objective
Add health checks to a Deployment using liveness and readiness probes, observe how Kubernetes responds to probe failures, and fix broken probes.

## Key Concepts

**Liveness Probe** — answers "Is this container still alive?" If it fails, Kubernetes restarts the container. Used to recover from deadlocks, hung processes, or broken application states.

**Readiness Probe** — answers "Is this container ready for traffic?" If it fails, Kubernetes removes the Pod from Service endpoints but does NOT restart it. Used to prevent sending requests to a container that's still starting up or temporarily unable to serve.

Both probes use the same mechanisms (HTTP GET, TCP socket, or exec command) but trigger different actions on failure.

## Task 1 — Add Liveness and Readiness Probes (add_liveness.yaml)
Created a Deployment called `probe-demo` with both probes configured:
- Liveness probe: HTTP GET to `/` on port 80, checks every 10 seconds, starts after 5 seconds
- Readiness probe: HTTP GET to `/` on port 80, checks every 5 seconds, starts after 3 seconds

Since nginx responds with 200 on `/`, both probes pass. Verified with `kubectl describe pod -l app=probe-demo`, which showed:
- `Liveness: http-get http://:80/ delay=5s timeout=1s period=10s #success=1 #failure=3`
- `Readiness: http-get http://:80/ delay=3s timeout=1s period=5s #success=1 #failure=3`

Pod stayed at `Ready: True` with 0 restarts — healthy behavior confirmed.

## Task 2 — Break Probes Intentionally (add_liveness_with_failure.yaml)
Created a second Deployment called `probe-fail-demo` with both probes pointing to `/nonexistent` — a path that returns 404 from nginx.

Observed behavior:
- **Readiness probe failed immediately** — Pod showed `Ready: False` (0/1 READY), meaning it would receive zero traffic from any Service
- **Liveness probe failed after 3 consecutive checks** — Kubernetes killed and restarted the container
- **Restart count kept climbing** (reached 2+ within a minute) because each new container also failed the probe
- Events showed the full failure chain: `Liveness probe failed: HTTP probe failed with statuscode: 404` → `Container nginx failed liveness probe, will be restarted`

This demonstrates the difference: readiness failure removes traffic, liveness failure triggers a restart.

## Task 3 — Fix the Probes (add_liveness_fixed.yaml)
Applied a corrected version with probes pointing back to `/` (valid path). Kubernetes rolled out a new Pod that immediately passed both probes:
- Pod showed `1/1 Ready` with 0 restarts
- The broken Pod was replaced by the fixed one

This demonstrates the real-world fix cycle: identify the failing probe path in describe/events, correct the YAML, and re-apply.

## Probe Configuration Reference

| Field           | What It Does |
| `initialDelaySeconds` | Wait this long before first probe (give app time to start) |
| `periodSeconds` | How often to probe |
| `timeoutSeconds` | How long to wait for a response before marking as failed |
| `failureThreshold` | How many consecutive failures before taking action |
| `successThreshold` | How many consecutive successes to mark as passing |

## Troubleshooting Notes
- Continued running with 1 replica per Deployment to stay within 8GB RAM constraints
- Deleted completed Deployments before creating new ones to minimize memory pressure
- The `nginx-deployment` from Lab 01 remained running throughout with 1 restart (from earlier etcd recovery)

## Deliverables
- `add_liveness.yaml` — Deployment with working liveness and readiness probes
- `add_liveness_with_failure.yaml` — Deployment with intentionally broken probes (path: /nonexistent)
- `add_liveness_fixed.yaml` — Corrected version with working probes
- `lab03.sh` — Commands used throughout the lab
- `lab03.txt` — Output evidence (pod status, describe output showing probe failures and restarts)
