# Lab 04 – Deployment Strategies

## Objective
Perform a rolling update (Deployment + YAML), observe rollout behavior, simulate a bad release, and roll back safely. Document pros/cons of strategies.

## What We Did

### Rolling update (deployment-strategy.yaml)
- Deployment `rolling-demo` (per solutions/deployment-strategy.yaml) with `strategy.type: RollingUpdate`, `maxSurge: 1`, `maxUnavailable: 0`.
- Baseline image `nginx:1.27`. Applied and waited for rollout to complete.

### Bad release (bad-release.yaml)
- Same Deployment name; image changed to `nginx:99.99.99` (does not exist).
- New ReplicaSet created; new Pods go to ImagePullBackOff; old Pods stay Running until new ones are Ready (which never happens).
- No downtime because old Pods are not terminated until new ones are Ready.

### Rollback
- `kubectl rollout undo deployment/strategy-demo` reverted to the previous revision.
- New ReplicaSet scaled down, previous one scaled up; workload back to `nginx:1.27`.
- `kubectl rollout history` shows revisions.

## Evidence of rollout and rollback

- **Rollout**: `kubectl rollout status` and `kubectl get pods` show new Pods coming up and old ones terminating when using a valid image.
- **Bad release**: `kubectl get pods` shows ImagePullBackOff for the new ReplicaSet; old Pods still Ready.
- **Rollback**: `kubectl rollout undo` plus `rollout status` and `rollout history` show the revert to the previous revision.

## Deployment strategies – pros and cons

| Strategy        | How it works                    | Pros                          | Cons                                |
|----------------|----------------------------------|-------------------------------|-------------------------------------|
| **Rolling**    | Replace Pods gradually; new must be Ready before old are removed. | No downtime, built-in, simple. | Slower at scale; two versions run during update. |
| **Recreate**   | Terminate all old Pods, then create new ones. | Simple, no mixed versions.     | Downtime during replacement.        |
| **Blue-Green** | Two full environments; switch traffic in one step. | Instant switch, easy rollback (switch back). | Double resources; more ops to manage. |
| **Canary**     | Small % of traffic to new version; increase gradually. | Lower risk; catch issues early. | Needs traffic splitting and monitoring. |

Rolling is the default in Kubernetes (maxSurge/maxUnavailable control pace). Blue-Green and Canary are usually implemented with multiple Deployments/Services or an ingress/mesh.

## Deliverables

- **deployment-strategy.yaml**: Deployment `rolling-demo` with RollingUpdate (per solutions).
- **bad-release.yaml**: Same Deployment with a bad image for rollback demo.
- **lab04.sh**: apply baseline, apply bad release, rollout undo, history.
- **lab04_notes.md**: this file (rollout/rollback evidence, strategy pros/cons).
