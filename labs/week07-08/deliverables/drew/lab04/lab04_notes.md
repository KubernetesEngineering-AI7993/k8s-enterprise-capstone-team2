# Lab 04 - Deployment Strategies



## Objective

Perform a rolling update using Helm, observe rollout behavior, simulate a bad release, and roll back safely.



## What We Did



### Rolling Update via Helm

Installed sample-app with nginx:1.26 (revision 1), then upgraded to nginx:1.27 (revision 2). Helm triggered a rolling update — Kubernetes gradually replaced old Pods with new ones. The upgrade was seamless with zero downtime.



### Simulated Bad Release

Upgraded to nginx:99.99.99 (revision 3) — an image that does not exist. The new Pod was stuck in ContainerCreating/ImagePullBackOff while the old working Pod (nginx:1.27) stayed running. Application remained available because Kubernetes does not kill old Pods until new ones are Ready.



### Rollback

Ran helm rollback sample-app 2 to revert to revision 2 (nginx:1.27). This created revision 4. The bad Pod was terminated and the working version was restored instantly.



### Helm History

REVISION 1: Install (nginx:1.26)

REVISION 2: Upgrade (nginx:1.27)

REVISION 3: Bad release (nginx:99.99.99)

REVISION 4: Rollback to 2 (nginx:1.27)



## Deployment Strategies - Pros and Cons



### Rolling Update

How: Replace Pods one at a time. New Pod must be Ready before old Pod is killed.

Pros: Zero downtime, built into Kubernetes, simple to configure.

Cons: Slow for large deployments, both versions run simultaneously during update.

Config: maxSurge (extra Pods allowed) and maxUnavailable (minimum Pods required).



### Blue-Green

How: Run two identical environments (blue = current, green = new). Switch traffic from blue to green all at once.

Pros: Instant switchover, easy rollback (switch traffic back to blue), no mixed versions.

Cons: Requires double the resources (two full environments running), more complex to set up.

Implementation: Two Deployments with a Service selector that points to one or the other.



### Canary

How: Route a small percentage of traffic (e.g., 5%) to the new version. Gradually increase if it looks healthy.

Pros: Low risk (only small % of users see new version), can catch issues before full rollout.

Cons: Complex traffic splitting, requires monitoring to decide when to promote, slower rollout.

Implementation: Service mesh (Istio) or weighted routing via ingress controller.



## Deliverables

- lab04_notes.md: this file

- lab04.txt: output evidence 

