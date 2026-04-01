# Lab 01 – GitOps Using ArgoCD: Notes & Workflow Explanation
---

## What is GitOps?

GitOps is an operational model where **Git is the single source of truth** for
the desired state of your infrastructure and applications. Changes are made by
committing to Git — never by directly running `kubectl apply` or `helm install`
in production. An operator (ArgoCD in this case) continuously watches the repo
and reconciles the live cluster state to match what Git declares.

The four core GitOps principles:
1. **Declarative** – the entire system is described declaratively (YAML manifests / Helm values)
2. **Versioned** – all desired state is stored in Git, giving full audit history
3. **Pulled automatically** – the operator pulls and applies changes, rather than a CI pipeline pushing
4. **Continuously reconciled** – if the live state drifts from Git, the operator corrects it

---

## Step-by-Step: What Was Done

### 1. Install ArgoCD
ArgoCD was installed using the official upstream manifest into the `argocd`
namespace. The `argocd-server` service was patched to `NodePort 30080` so it is
reachable from the host machine through Kind's port mapping.

```bash
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Create the ArgoCD Application
The `argocd-app.yaml` manifest declares an `Application` resource telling ArgoCD:
- **Where** to find the source: `helm/adguard-home/` in this repo on `kunal/week09-10`
- **Where** to deploy: the `adguard-home` namespace on `https://kubernetes.default.svc`
- **How** to sync: automatically, with `selfHeal: true` and `prune: true`

```bash
kubectl apply -f labs/week09-10/Deliverables/kunal/lab01/argocd-app.yaml
```

### 3. Enable Auto-Sync
Auto-sync is declared directly in the Application manifest under `syncPolicy.automated`.
This means ArgoCD will apply any change pushed to the branch within ~3 minutes
without any manual intervention.

```yaml
syncPolicy:
  automated:
    prune: true      # removes resources that are deleted from Git
    selfHeal: true   # reverts manual changes made directly to the cluster
```

---

## Demonstrating Auto-Sync

**Procedure:**
1. Edit `helm/adguard-home/values.yaml` — for example, change `replicas: 1` → `replicas: 2`
2. Commit and push to `kunal/week09-10`
3. ArgoCD detects the diff within ~3 minutes (or trigger manually: `argocd app sync adguard-home`)
4. ArgoCD applies the change — the deployment scales up to 2 pods

**What to observe:**
```bash
# Watch sync status
argocd app get adguard-home --watch

# Confirm pods scaled
kubectl get pods -n adguard-home
```

---

## Demonstrating Drift Detection & Reconciliation

Drift occurs when the **live cluster state** diverges from what Git declares.
Because `selfHeal: true` is set, ArgoCD automatically corrects this.

**Procedure:**
```bash
# Manually scale down to 0 (simulating someone running kubectl directly)
kubectl scale deployment -n adguard-home \
  -l app.kubernetes.io/name=adguard-home --replicas=0

# Within ~30s, ArgoCD detects OutOfSync and restores 1 replica
argocd app get adguard-home
kubectl get pods -n adguard-home
```

**What happens:**
1. ArgoCD's controller loop sees `desired = 1 replica` (from Git) but `actual = 0`
2. Status changes to `OutOfSync`
3. Because `selfHeal: true`, ArgoCD immediately triggers a sync
4. Deployment is restored to 1 replica — the manual change is **overwritten**

This is the core value proposition of GitOps: **the cluster always converges back
to what Git says**, making Git the only authoritative way to change anything.

---

## Key ArgoCD CLI Commands Used

| Command | Purpose |
|---|---|
| `argocd login localhost:30080 --insecure` | Authenticate to ArgoCD |
| `argocd app create` / `kubectl apply -f argocd-app.yaml` | Register Application |
| `argocd app sync adguard-home` | Manually trigger sync |
| `argocd app get adguard-home` | View sync/health status |
| `argocd app get adguard-home --watch` | Live status updates |
| `argocd app history adguard-home` | View sync history |
| `argocd app diff adguard-home` | See what would change |

---

## Why Helm + ArgoCD?

Rather than applying raw YAML, we use a Helm chart (via `bjw-s/app-template`) because:
- **Templating** – a single `values.yaml` change controls replicas, image tags, ports
- **Versioning** – the chart version and app version are pinned in `Chart.yaml`
- **GitOps fit** – ArgoCD natively renders Helm charts and tracks the diff at the values level
- **No `helm install` in CI** – ArgoCD owns the deployment, not a pipeline script

ArgoCD renders the Helm chart server-side and applies the resulting manifests,
so the Git repo never needs to contain pre-rendered YAML.
