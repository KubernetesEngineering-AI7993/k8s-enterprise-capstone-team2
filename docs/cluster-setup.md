# Cluster Setup

This setup reflects the current `scripts/cluster-setup.sh` flow and current manifests.

## Quick Start (Recommended)

From the repo root:

```bash
bash scripts/cluster-setup.sh
```

The script is interactive. It prints the target context, repo, and branch, then asks for confirmation before making changes. It can also prompt for object-store credentials if `k8s/base/sealed-secret.yaml` still contains the placeholder sentinel string.

The script handles:

1. Preflight checks (`kubectl`, `helm`, `kubeseal`)
2. Optional kind cluster creation if no kube context is set
3. Helm repo setup
4. Sealed Secrets controller install
5. SealedSecret placeholder check and optional interactive sealing
6. Argo CD install
7. GitOps AppProject/Application apply
8. ingress-nginx install
9. kube-prometheus-stack install
10. Argo CD sync wait and output summary

## Prerequisites

- `kubectl`
- `helm`
- `kubeseal`
- `kind` when auto-creating a local cluster
- `rg`/ripgrep when auto-creating a local kind cluster, because the script uses it to check for an existing cluster name

Optional:

- `argocd` CLI for manual sync/debug
- `docker` if you need to build and load the local application images

## Application Images

The Kubernetes manifests reference local-style image tags and set `imagePullPolicy: IfNotPresent`:

- `intake-service:v6`
- `detection-service:v1`
- `dashboard:v4`

For kind or any cluster that cannot pull these tags from a registry, build and load them before or after bootstrap:

```bash
./Docker/build-images.sh --load-kind
```

The intake image build requires image files under `Docker/intake-service/images/`; those dataset images are not committed to the repo. The detection model file `Docker/detection-service/best.pt` is committed.

## Script Configuration

The script supports environment overrides:

- `REPO_URL` (used in script output; default project repo URL)
- `TARGET_BRANCH` (used in script output; default `mlops`)
- `APP_NAMESPACE` (default `warehouse-cv`)
- `ARGOCD_NAMESPACE` (default `argocd`)
- `CREATE_KIND_IF_MISSING` (default `true`)
- `KIND_CLUSTER_NAME` (default `warehouse-cv`)
- `KIND_CONFIG_FILE` (default `k8s/kind/kind.yaml`)
- Version pins:
  - `ARGOCD_CHART_VERSION` (default `9.5.0`)
  - `ARGOCD_IMAGE_TAG` (default `v3.3.6`)
  - `SEALED_SECRETS_VERSION` (default `2.18.4`)
  - `PROM_STACK_VERSION` (default `82.4.0`)
  - `INGRESS_NGINX_VERSION` (default `4.15.1`)

Important: `REPO_URL` and `TARGET_BRANCH` do not rewrite the Argo CD Application manifests. The current Application YAML files hard-code the repo URL and `targetRevision: mlops`; update those manifests if you need Argo CD to track a different remote or branch.

## Local kind Behavior

If no kube context exists and `CREATE_KIND_IF_MISSING=true`, the script creates:

- kind cluster named `warehouse-cv`
- node layout from `k8s/kind/kind.yaml` using Kubernetes `v1.30.0`
- one control-plane node and two worker nodes
- host port mappings on the control-plane node:
  - host `80` -> ingress-nginx HTTP nodePort `30080`
  - host `443` -> ingress-nginx HTTPS nodePort `30443`

The default kind cluster does not include GPU-labelled nodes. The `model-finetune` CronJob is applied, but its pods require `node-type: gpu`, a `gpu=true:NoSchedule` toleration, and `nvidia.com/gpu: 1`, so they will not schedule on the default kind nodes.

## Manual Setup (Equivalent)

If you do not use the script, run these high-level steps in order:

1. Add/update Helm repos (`sealed-secrets`, `argo`, `ingress-nginx`, `prometheus-community`).
2. Install Sealed Secrets in `kube-system`.
3. Ensure `k8s/base/sealed-secret.yaml` contains values sealed for this cluster's Sealed Secrets controller.
4. Install Argo CD in `argocd`.
5. Apply:
   - `gitops/argocd/warehouse-cv-project.yaml`
   - `gitops/argocd/warehouse-cv-dev-application.yaml`
   - `gitops/argocd/warehouse-cv-addons-dev-application.yaml`
6. Install ingress-nginx.
7. Install kube-prometheus-stack in `monitoring` with ServiceMonitor selection enabled across Helm releases/namespaces, matching the script's Helm values.

Important: application resources, monitoring resources, and system ingress are synced by Argo CD from `k8s/overlays/dev` and `k8s/overlays/addons-dev`; they are not separate manual `kubectl apply` steps in the current design.

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

- `warehouse-cv-dev` and `warehouse-cv-addons-dev` apps exist and eventually sync.
- Services, deployments, HPAs, the training CronJob, and ingress objects exist in `warehouse-cv`.
- The monitoring stack exists in `monitoring`.
- The `warehouse-cv` ServiceMonitor exists, but app metric scraping is not useful until the Flask services expose `/metrics`.

## Access Endpoints

- Dashboard: `http://dashboard.warehouse-cv.internal`
- Intake: `http://intake.warehouse-cv.internal`
- Inference: `http://inference.warehouse-cv.internal`
- Argo CD: `https://argocd.warehouse-cv.internal`
- Prometheus: `http://prometheus.warehouse-cv.internal`
- Grafana: `http://grafana.warehouse-cv.internal`

If host routing is not configured yet, use `kubectl port-forward` as needed. The script summary prints port-forward commands for Argo CD and Grafana, including the initial Argo CD admin password and the default Grafana password from kube-prometheus-stack.
