# Cluster Setup

This setup reflects the current `scripts/cluster-setup.sh` flow and current manifests.

## Quick Start (Recommended)

From the repo root:

```bash
bash scripts/cluster-setup.sh
```

The script handles:

1. Preflight checks (`kubectl`, `helm`, `kubeseal`)
2. Optional kind cluster creation if no kube context is set
3. Helm repo setup
4. Sealed Secrets controller install
5. Argo CD install
6. GitOps app/project apply
7. Ingress NGINX install
8. kube-prometheus-stack install
9. Argo CD sync wait and output summary

## Prerequisites

- `kubectl`
- `helm`
- `kubeseal`
- `kind` (only required when auto-creating local cluster)

Optional:

- `argocd` CLI for manual sync/debug

## Script Configuration

The script supports environment overrides:

- `REPO_URL` (default project repo URL)
- `TARGET_BRANCH` (default `mlops`)
- `CREATE_KIND_IF_MISSING` (default `true`)
- `KIND_CLUSTER_NAME` (default `warehouse-cv`)
- `KIND_CONFIG_FILE` (default `k8s/kind/kind.yaml`)
- Version pins:
  - `ARGOCD_CHART_VERSION`
  - `ARGOCD_IMAGE_TAG`
  - `SEALED_SECRETS_VERSION`
  - `PROM_STACK_VERSION`
  - `INGRESS_NGINX_VERSION`

## Local kind Behavior

If no kube context exists and `CREATE_KIND_IF_MISSING=true`, the script creates:

- kind cluster named `warehouse-cv`
- node layout from `k8s/kind/kind.yaml` (1 control-plane, 2 workers)
- host port mappings:
  - `80` -> ingress-nginx HTTP nodePort
  - `443` -> ingress-nginx HTTPS nodePort

## Manual Setup (Equivalent)

If you do not use the script, run these high-level steps in order:

1. Add/update Helm repos (`sealed-secrets`, `argo`, `ingress-nginx`, `prometheus-community`).
2. Install Sealed Secrets in `kube-system`.
3. Install Argo CD in `argocd`.
4. Apply:
   - `gitops/argocd/warehouse-cv-project.yaml`
   - `gitops/argocd/warehouse-cv-dev-application.yaml`
   - `gitops/argocd/warehouse-cv-addons-dev-application.yaml`
5. Install ingress-nginx.
6. Install kube-prometheus-stack in `monitoring`.

Important: monitoring resources and system ingress are synced by Argo CD from `k8s/overlays/addons-dev`; they are not a separate manual apply step in current design.

## Hosts You Should Map

Add DNS or `/etc/hosts` entries for:

- `intake.warehouse-cv.internal`
- `inference.warehouse-cv.internal`
- `dashboard.warehouse-cv.internal`
- `argocd.warehouse-cv.internal`
- `prometheus.warehouse-cv.internal`
- `grafana.warehouse-cv.internal`

For kind, map all six to `127.0.0.1`.

## Verify Deployment

```bash
kubectl get ns
kubectl get all -n warehouse-cv
kubectl get app -n argocd
kubectl get ingress -n warehouse-cv
kubectl get ingress -n argocd
kubectl get ingress -n monitoring
kubectl get servicemonitor -n warehouse-cv
```

Expected result:

- `warehouse-cv-dev` and `warehouse-cv-addons-dev` apps exist and sync.
- Services, deployments, and ingress objects exist in `warehouse-cv`.
- Monitoring stack exists in `monitoring`.

## Access Endpoints

- Dashboard: `http://dashboard.warehouse-cv.internal`
- Argo CD: `https://argocd.warehouse-cv.internal`
- Prometheus: `http://prometheus.warehouse-cv.internal`
- Grafana: `http://grafana.warehouse-cv.internal`

If host routing is not configured yet, use `kubectl port-forward` as needed.
