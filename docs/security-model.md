# Security Model

This file describes the controls currently present in the repo and the most important remaining gaps.

## Identity and RBAC

Implemented:

- Dedicated service accounts in `warehouse-cv`:
  - `trainer-sa`
  - `intake-sa`
  - `inference-sa`
  - `dashboard-sa`
- Namespace-scoped read-only RBAC for dashboard (`pods`, `services`, `endpoints`, `configmaps` via Role + RoleBinding).

Gaps:

- Argo CD AppProject currently allows wildcard cluster and namespace resources (`*/*`), which is broader than least privilege.

## Pod Security

Implemented:

- Dev overlay enforces Pod Security labels (`restricted`) on namespace `warehouse-cv`.
- Workloads set `runAsNonRoot`, explicit `runAsUser`, and `seccompProfile: RuntimeDefault`.
- Containers disable privilege escalation and drop all capabilities.

Notes:

- `readOnlyRootFilesystem` is currently `false` for containers.

## Network Security

Implemented in `k8s/overlays/dev/network-policies.yaml`:

- default deny ingress for all pods
- explicit ingress allows:
  - ingress-nginx -> `footage-intake`
  - `cv-inference` -> `footage-intake`
  - `results-dashboard` -> `footage-intake`
  - ingress-nginx -> `cv-inference`
  - `results-dashboard` -> `cv-inference`
  - ingress-nginx -> `results-dashboard`

Effect:

- East-west and north-south traffic is explicit instead of open by default.

## Secrets and Sensitive Configuration

Implemented:

- Credentials delivered through `SealedSecret` (`k8s/base/sealed-secret.yaml`) into secret `warehouse-cv-secret`.
- `model-finetune` consumes config and secret via `envFrom`.

Operational note:

- `scripts/cluster-setup.sh` still contains placeholder-detection logic that checks for a sentinel string not present in the current sealed file.

## Change Control and Drift Protection

Implemented:

- CI (`.github/workflows/capstone-platform-ci.yaml`) validates YAML and rendered manifests.
- Argo CD applications auto-sync, prune, and self-heal from Git.

Gaps:

- No image scanning or signing enforcement in pipeline.
- No policy-as-code admission checks (Kyverno/Gatekeeper/OPA) in this repo.
- No explicit secret rotation runbook beyond resealing and committing updated values.

## Current Security Priorities

1. Tighten Argo CD project permissions (source repos, resource whitelists).
2. Add image vulnerability scanning to CI.
3. Add policy checks for pod hardening and namespace constraints.
4. Add service-level metrics and alerts for security-relevant failures.
