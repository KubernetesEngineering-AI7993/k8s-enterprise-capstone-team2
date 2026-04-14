# Cluster Setup — Warehouse CV Platform

This document walks through the full bootstrap of the warehouse-cv platform from a blank cluster to a running, GitOps-managed deployment with monitoring.

The companion script [`scripts/cluster-setup.sh`](../scripts/cluster-setup.sh) automates every step below.

---

## Prerequisites

| Tool | Purpose | Install |
|---|---|---|
| `kubectl` | Cluster interaction | [docs](https://kubernetes.io/docs/tasks/tools/) |
| `helm` ≥ 3.14 | Chart installs | [docs](https://helm.sh/docs/intro/install/) |
| `kubeseal` | Encrypting credentials | [docs](https://github.com/bitnami-labs/sealed-secrets#installation) |
| `kind` (recommended) | Auto-create local multi-node cluster when no kube context exists | [docs](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) |
| `argocd` CLI (optional) | Watching sync status | [docs](https://argo-cd.readthedocs.io/en/stable/cli_installation/) |

The script supports two startup modes:

- Existing cluster context in `kubeconfig` (uses it as-is)
- No context set (auto-creates a local `kind` cluster with 1 control-plane + 2 workers by default)

To disable auto-create and require an existing context:

```bash
export CREATE_KIND_IF_MISSING=false
```

To customize kind cluster shape:

```bash
export KIND_CLUSTER_NAME="warehouse-cv"
export KIND_WORKER_COUNT=2
export KIND_NODE_IMAGE="kindest/node:v1.30.0"
```

If you are not using auto-kind, your `kubeconfig` must point at the target cluster before running anything:

```bash
kubectl config current-context   # confirm the right cluster
```

---

## Running the Automated Script

```bash
# Clone and enter the repo
git clone https://github.com/example-org/k8s-enterprise-capstone-team2.git
cd k8s-enterprise-capstone-team2
git checkout mlops

# Optional: override defaults
export REPO_URL="https://github.com/your-org/k8s-enterprise-capstone-team2.git"
export TARGET_BRANCH="mlops"
export KIND_WORKER_COUNT=2

# Run
bash scripts/cluster-setup.sh
```

The script is fully idempotent — safe to re-run against a partially bootstrapped cluster.

When running on `kind`, the script configures ingress-nginx as `NodePort` and maps localhost ports:
- `http://127.0.0.1:80` -> ingress-nginx nodePort `30080`
- `https://127.0.0.1:443` -> ingress-nginx nodePort `30443`

---

## Manual Step-by-Step

### 1. Add Helm Repositories

```bash
helm repo add sealed-secrets        https://bitnami-labs.github.io/sealed-secrets
helm repo add argo                  https://argoproj.github.io/argo-helm
helm repo add ingress-nginx         https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community  https://prometheus-community.github.io/helm-charts
helm repo update
```

---

### 2. Install Sealed Secrets Controller

The Sealed Secrets controller is the cluster-side decryption engine. It must be running before you can create any `SealedSecret` resources.

```bash
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace kube-system \
  --set fullnameOverride=sealed-secrets \
  --wait
```

Verify:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

---

### 3. Seal Credentials

The plaintext `Secret` has been removed from source. You must seal real credentials and commit the result before Argo CD can create the `warehouse-cv-secret` in the cluster.

```bash
kubectl create secret generic warehouse-cv-secret \
  --namespace warehouse-cv \
  --from-literal=OBJECT_STORE_ACCESS_KEY=<your-key> \
  --from-literal=OBJECT_STORE_SECRET_KEY=<your-secret> \
  --dry-run=client -o yaml \
| kubeseal \
    --controller-namespace kube-system \
    --controller-name sealed-secrets \
    --format yaml \
> k8s/base/sealed-secret.yaml

git add k8s/base/sealed-secret.yaml
git commit -m "seal object store credentials"
git push origin mlops
```

The resulting file is safe to commit — encrypted values are bound to your cluster's controller key.

> **Rotating credentials:** Re-run the command above with the new values and push the updated file. Argo CD will detect the change and apply it automatically.

---

### 4. Install Argo CD

```bash
kubectl create namespace argocd

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type=ClusterIP \
  --wait
```

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Access the UI:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# open https://localhost:8080  (username: admin)
```

---

### 5. Apply GitOps Manifests

> **Before this step:** Update `repoURL` in `gitops/argocd/warehouse-cv-dev-application.yaml` to your actual Git remote if it still points at the placeholder.

```bash
kubectl apply -f gitops/argocd/warehouse-cv-project.yaml
kubectl apply -f gitops/argocd/warehouse-cv-dev-application.yaml
```

This creates:
- **`AppProject` `warehouse-cv`** — scopes deployments to the `warehouse-cv` namespace only
- **`Application` `warehouse-cv-dev`** — syncs `k8s/overlays/dev` from the `mlops` branch with auto-sync, prune, and self-heal enabled

From this point on, every push to `mlops` is automatically applied to the cluster. To trigger a manual sync:

```bash
argocd app sync warehouse-cv-dev
```

What Argo CD applies from `k8s/overlays/dev`:

| Resource | Source |
|---|---|
| Namespace, ConfigMap, PVC, ServiceAccounts, RBAC | `k8s/base/platform.yaml` |
| SealedSecret (→ decrypted Secret in cluster) | `k8s/base/sealed-secret.yaml` |
| Deployments: `footage-intake`, `cv-inference`, `results-dashboard` | `k8s/base/platform.yaml` |
| CronJob `model-finetune` (nightly GPU fine-tune) | `k8s/base/platform.yaml` |
| Services, HPAs, Ingress | `k8s/base/platform.yaml` |
| Multi-container demo Pod | `k8s/base/multi-container-placeholder.yaml` |
| NetworkPolicies (default-deny + explicit allows) | `k8s/network-policies/policies.yaml` |
| Namespace Pod Security labels (`restricted`) | `k8s/pod-security/namespace-patch.yaml` |
| Dev replica patch (all deployments → 1 replica) | `k8s/overlays/dev/replicas-patch.yaml` |

---

### 6. Install NGINX Ingress Controller

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --wait
```

For cloud/VM clusters, get the external IP and add entries to `/etc/hosts` (or your DNS):

```bash
INGRESS_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "${INGRESS_IP}  intake.warehouse-cv.local" | sudo tee -a /etc/hosts
echo "${INGRESS_IP}  inference.warehouse-cv.local" | sudo tee -a /etc/hosts
echo "${INGRESS_IP}  dashboard.warehouse-cv.local" | sudo tee -a /etc/hosts
```

For `kind`, use localhost:

```bash
echo "127.0.0.1 intake.warehouse-cv.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 inference.warehouse-cv.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 dashboard.warehouse-cv.local" | sudo tee -a /etc/hosts
```

---

### 7. Install Monitoring (Prometheus + Grafana)

```bash
kubectl create namespace monitoring

helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.sidecar.dashboards.enabled=true \
  --set grafana.sidecar.dashboards.searchNamespace=ALL \
  --wait
```

Apply the platform-specific monitoring resources (these are outside the Kustomize overlay and must be applied separately):

```bash
kubectl apply -f monitoring/prometheus/servicemonitor.yaml
kubectl apply -f monitoring/grafana/warehouse-cv-overview-dashboard-configmap.yaml
```

Access Grafana:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# open http://localhost:3000  (username: admin  password: prom-operator)
```

The **Warehouse CV Overview** dashboard will appear under *General* once the sidecar detects the ConfigMap. Panels include:
- **Inference Throughput** — `sum(rate(inference_frames_processed_total[5m]))`
- **Queue Backlog** — `sum(intake_frame_queue_depth)`

---

## Verifying the Deployment

```bash
# All resources in the namespace
kubectl get all -n warehouse-cv

# Argo CD application health and sync status
kubectl -n argocd get app warehouse-cv-dev

# HPA state
kubectl get hpa -n warehouse-cv

# Network policies
kubectl describe networkpolicy -n warehouse-cv

# Confirm RBAC for dashboard service account
kubectl auth can-i list pods \
  --as=system:serviceaccount:warehouse-cv:dashboard-sa \
  -n warehouse-cv

# Events (useful for troubleshooting scheduling/policy issues)
kubectl get events -n warehouse-cv --sort-by=.metadata.creationTimestamp
```

---

## Architecture Overview

```
Internet
   │
   ▼
ingress-nginx (LoadBalancer)
   │
   ├──▶ dashboard.warehouse-cv.local  ──▶  results-dashboard :8080
   ├──▶ intake.warehouse-cv.local     ──▶  footage-intake    :8081  (no NetworkPolicy allow yet)
   └──▶ inference.warehouse-cv.local  ──▶  cv-inference      :8082  (no NetworkPolicy allow yet)

footage-intake ──[NetworkPolicy allow]──▶ cv-inference
                                              │
                                         PVC: model-artifacts-pvc
                                              │
                                    CronJob: model-finetune (02:00, GPU nodes)

Argo CD (argocd ns) ──watches──▶ github.com/.../mlops @ k8s/overlays/dev
                     ──applies──▶ warehouse-cv namespace

Prometheus (monitoring ns) ──scrapes /metrics──▶ footage-intake, cv-inference, results-dashboard
Grafana    (monitoring ns) ──reads──▶ Prometheus
```

---

## Troubleshooting

| Symptom | Check |
|---|---|
| Pods `Pending` | `kubectl describe pod <name> -n warehouse-cv` — likely GPU node unavailable |
| `SealedSecret` not decrypting | `kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets` |
| Argo CD `OutOfSync` | Check `repoURL` is correct and branch `mlops` exists |
| Ingress not routing | Verify `ingress-nginx` pod is running and LoadBalancer IP is assigned |
| Metrics missing in Grafana | Confirm `ServiceMonitor` label `release: kube-prometheus-stack` matches the Helm release name |
| NetworkPolicy blocking traffic | `kubectl describe networkpolicy -n warehouse-cv` — intake→inference is allowed; ingress→intake/inference is not yet whitelisted |

See [`docs/troubleshooting-report.md`](troubleshooting-report.md) for a full runbook.
