# Lab 01 – Resource Requests & Limits

## Goal
Learn how Kubernetes “reserves” resources (requests) and enforces “hard caps” (limits), then intentionally cause an OOMKilled.

## What I did
1) Deployed a workload with NO requests/limits.
2) Used `kubectl top` to observe CPU/memory usage.
3) Updated the Deployment YAML to include CPU/memory requests + limits.
4) Created an intentional OOM scenario.

## What it means (plain language)
- **Request** = “this pod needs at least X.” The scheduler uses this when choosing a node.
- **Limit** = “this pod must not exceed Y.” The node enforces this.
- If a container exceeds its **memory limit**, it can get killed by the system → Kubernetes shows **OOMKilled**.

## What I looked for as proof
- `kubectl describe pod` shows resources under the container.
- `kubectl top pods` shows usage numbers.
- OOM pod shows `OOMKilled` in `describe` and/or events.

## Takeaway
Requests affect **where** a pod can run. Limits affect **how much** a pod is allowed to use once it is running.
