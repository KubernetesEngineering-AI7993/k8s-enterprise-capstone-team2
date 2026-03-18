# Release Notes (Week 07–08)

Per **reports/release-notes.md**: students must document the following. This mirrors real release documentation in enterprise teams.

- How the application was packaged  
- How releases are triggered  
- How rollbacks are handled  
- What could go wrong in production  

---

## How the application was packaged

- **Container image**: The app is assumed to be packaged as a container image (e.g. `nginx:1.27` or a custom app image). The image is referenced in the Helm chart (`values.yaml`: `image.repository`, `image.tag`) and in raw Deployment manifests (e.g. lab04).
- **Helm chart**: The primary packaging is the **sample-app** Helm chart (lab01; see solutions/helm). It includes a parameterized Deployment (replica count, image tag) and Service (type, port). Default values in `values.yaml`; overrides via `--set` or `-f values-*.yaml`.
- **Raw manifests**: Lab04 uses the **rolling-demo** Deployment (solutions/deployment-strategy.yaml) with a rolling update strategy for demonstration.
- **CI**: The pipeline (lab03; solutions/ci-pipeline.yaml) runs on push and performs a deploy step (extensible to validate, build, and deploy in production).

---

## How releases are triggered

- **CI on push**: The GitHub Actions workflow (lab03) runs on **push** (per solutions/ci-pipeline.yaml). In practice, “release” is often “merge to main,” which triggers the pipeline; the deploy stage would apply to a target cluster (e.g. staging or production).
- **Manual release**: Operators can run `helm upgrade --install sample-app ./sample-app --set image.tag=<version>` or `kubectl set image deployment/...` (or apply updated YAML) to release a specific version.
- **Rolling update**: When the Pod template changes (e.g. new image tag), Kubernetes performs a rolling update. New Pods are created and, once Ready, traffic is shifted; old Pods are terminated. No separate “release trigger” is needed beyond applying the new spec.

---

## How rollbacks are handled

- **Helm**: `helm rollback sample-app <revision>` reverts the release to a previous revision. Helm reapplies the exact manifests from that revision (e.g. previous image tag and replica count). Revision history is visible with `helm history sample-app`.
- **Kubernetes Deployment**: `kubectl rollout undo deployment/<name>` reverts to the previous rollout revision. The controller scales down the current ReplicaSet and scales up the previous one. More control is possible with `kubectl rollout undo deployment/<name> --to-revision=<n>`.
- **Safety**: Both mechanisms rely on the cluster’s rollout history. With a rolling strategy and `maxUnavailable: 0`, old Pods stay up until new ones are Ready, so a bad release (e.g. wrong image) can be rolled back without downtime by undoing the rollout or performing a Helm rollback.

---

## What could go wrong in production

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Bad or missing image** | Wrong tag or image not in registry → ImagePullBackOff; new Pods never become Ready. | Use immutable tags or SHA; validate image exists in CI; monitor rollout status and set alerts. |
| **Broken readiness/liveness** | Probes too strict or wrong path → Pods never Ready or repeated restarts. | Test probes in staging; use conservative initialDelaySeconds/periodSeconds; align probe path with app. |
| **No rollback practice** | Team doesn’t know how to roll back or history is lost. | Document and drill rollback (Helm rollback, `kubectl rollout undo`); keep sufficient revision history. |
| **Config vs code drift** | values.yaml or ConfigMaps out of sync with what’s in Git or deployed. | Store all config in Git; deploy via CI; avoid one-off `--set` in production without recording. |
| **Pipeline deploys without checks** | Merge to main deploys straight to production with no validation. | Run tests and YAML validation in CI; use staging; optional manual approval or feature flags for prod. |
| **Resource or quota** | New replicas can’t schedule; rollout hangs. | Set resource requests/limits; monitor quota and capacity; use PDBs for critical apps. |
| **Secrets/credentials** | Wrong or missing secrets in the cluster. | Manage secrets via sealed-secrets or external secret stores; never commit secrets; rotate regularly. |

These points align with typical enterprise release documentation: how we package, how we release, how we roll back, and what we watch for in production.
