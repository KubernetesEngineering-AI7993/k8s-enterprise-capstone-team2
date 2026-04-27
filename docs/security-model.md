# Security Model

This file describes the controls currently present in the repo and the most important remaining gaps.

## Identity and RBAC

Implemented:

- Dedicated service accounts in `warehouse-cv`:
  - `trainer-sa`
  - `intake-sa`
  - `inference-sa`
  - `dashboard-sa`
- Namespace-scoped read-only RBAC for `dashboard-sa` (`pods`, `services`, `endpoints`, `configmaps` via Role + RoleBinding).

Notes:

- The current dashboard Flask app does not call the Kubernetes API, so the dashboard RoleBinding is provisioned but not exercised by the current runtime code.

Gaps:

- Argo CD AppProject currently allows `sourceRepos: ["*"]`, which allows any source repo.
- Argo CD AppProject currently allows wildcard cluster and namespace resources (`*/*`), which is broader than least privilege.

## Pod Security

Implemented:

- Dev overlay enforces Pod Security Admission labels (`restricted`) on namespace `warehouse-cv`.
- Workload pod specs set `runAsNonRoot`, explicit `runAsUser: 1000`, and `seccompProfile: RuntimeDefault`.
- Containers disable privilege escalation and drop all capabilities.

Notes:

- `readOnlyRootFilesystem` is currently `false` for containers.
- Pod Security Admission labels are applied to `warehouse-cv` by the dev overlay only. The `monitoring` namespace manifest in the add-ons overlay does not define equivalent Pod Security labels.
- The Dockerfiles for `intake-service` and `dashboard` do not set a non-root image user, but the Kubernetes pod security context runs them as UID `1000` at runtime.

## Network Security

Implemented in `k8s/overlays/dev/network-policies.yaml`:

- default deny ingress for all pods in `warehouse-cv`
- explicit ingress allows:
  - ingress-nginx -> `footage-intake`
  - `cv-inference` -> `footage-intake`
  - `results-dashboard` -> `footage-intake`
  - ingress-nginx -> `cv-inference`
  - `results-dashboard` -> `cv-inference`
  - ingress-nginx -> `results-dashboard`

Effect:

- Ingress to application pods is constrained to the expected north-south and app-to-app paths.

Gaps:

- NetworkPolicies are ingress-only. There is no default-deny egress policy, DNS egress allow-list, or external dependency egress policy in this repo.
- The policies depend on namespace labels such as `kubernetes.io/metadata.name: ingress-nginx`, which are expected on standard Kubernetes namespaces.

## Secrets and Sensitive Configuration

Implemented:

- Credentials are delivered through `SealedSecret` (`k8s/base/sealed-secret.yaml`) into secret `warehouse-cv-secret`.
- `model-finetune` consumes config and secret via `envFrom`.
- The setup script can interactively generate a sealed secret only when it detects the placeholder sentinel string `PLACEHOLDER_SEAL_WITH_KUBESEAL`.

Operational notes:

- The current sealed file contains encrypted values and does not contain the placeholder sentinel, so `scripts/cluster-setup.sh` treats it as already sealed.
- Sealed Secrets are cluster/controller specific. If deploying to a different cluster, reseal credentials for that cluster's controller before expecting Argo CD sync to succeed.
- `warehouse-cv-config` contains placeholder URIs for the model registry, footage source, and results store; these are not secrets, but they are not production-ready endpoint values.

## Runtime and Data Security Gaps

- The intake image bakes local dataset images into the container. The source image dataset is not committed, and there is no documented data provenance or sensitivity classification in this repo.
- The dashboard returns randomized fallback detections if inference is unavailable. This is useful for demos but can mask inference failures unless operators also check service health.
- The monitoring manifests create a ServiceMonitor and placeholder Grafana dashboard, but the Flask services do not expose `/metrics`; security-relevant runtime alerts are not implemented yet.
- The `model-finetune` job is configured for GPU nodes and consumes object-store credentials, but the repo does not include a training script, image hardening details, or secret rotation workflow for that job.

## Change Control and Drift Protection

Implemented:

- CI (`.github/workflows/capstone-platform-ci.yaml`) validates YAML and rendered manifests.
- Argo CD applications auto-sync, prune, and self-heal from Git.

Gaps:

- No image vulnerability scanning or image signing enforcement in CI.
- No policy-as-code admission checks (Kyverno/Gatekeeper/OPA) in this repo.
- No explicit secret rotation runbook beyond resealing and committing updated values.
- No CI check currently validates that runtime Flask routes match the ServiceMonitor or ingress expectations.

## Current Security Priorities

1. Tighten Argo CD project permissions by restricting `sourceRepos`, destinations, and resource whitelists.
2. Add image vulnerability scanning and image signing verification.
3. Add policy checks for pod hardening, namespace constraints, and network egress.
4. Add real application metrics and alerts for service health, inference failures, and secret-dependent training failures.
5. Document secret rotation, dataset handling, and production endpoint configuration.
