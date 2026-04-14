# Kubernetes Enterprise Capstone - Security Model

## Security Objectives

- Enforce least privilege access between workloads and operators.
- Restrict pod-level privilege escalation and unsafe defaults.
- Limit east-west network communication to required paths.
- Support GitOps-based change control for security-sensitive manifests.

## Identity and Access Controls

- Each workload has a dedicated ServiceAccount:
  - `trainer-sa`
  - `intake-sa`
  - `inference-sa`
  - `dashboard-sa`
- A namespace-scoped `Role` + `RoleBinding` grants `dashboard-sa` read-only access to discover local services/pods/configmaps.
- No broad cluster-admin role assignments are included in application manifests.

## Pod Security Standards

- Namespace labels enforce `restricted` Pod Security admission profile in the dev overlay.
- Pods use `securityContext` with:
  - `runAsNonRoot: true`
  - explicit `runAsUser`
  - `seccompProfile: RuntimeDefault`
- Containers drop all Linux capabilities and disable privilege escalation.

## Network Security

- Default deny ingress policy applies to all pods.
- Explicit allow policies are defined for:
  - `footage-intake` -> `cv-inference`
  - ingress controller namespace -> `results-dashboard`
- This model gives a secure default while preserving required traffic paths.

## Secret and Data Handling

- Sensitive values are isolated in Kubernetes `Secret` objects.
- Model artifacts are stored in a dedicated PVC and should be migrated to object storage in production.
- The next iteration should integrate sealed secrets or external secret manager support.

## Supply Chain and Pipeline Controls

- CI validates YAML structure and renders Helm + Kustomize output before merge.
- ArgoCD continuously reconciles desired state and self-heals drift.
- Recommended near-term additions:
  - image signing and provenance checks
  - vulnerability scanning (Trivy)
  - policy-as-code checks (Kyverno/Gatekeeper)
