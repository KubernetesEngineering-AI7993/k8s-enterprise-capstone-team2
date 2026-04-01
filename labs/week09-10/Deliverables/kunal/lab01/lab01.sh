#!/usr/bin/env bash
# =============================================================================
# Lab 01 – GitOps using ArgoCD
# Requirements: kind, kubectl, helm, argocd (CLI) installed
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/KubernetesEngineering-AI7993/k8s-enterprise-capstone-team2.git"
BRANCH="kunal/week09-10"
ARGOCD_NS="argocd"
APP_NS="adguard-home"
APP_NAME="adguard-home"
ARGOCD_NODEPORT="30080"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color helpers
info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
section() { echo -e "\n\033[1;35m========== $* ==========\033[0m"; }

# =============================================================================
# STEP 0 – Tear down any existing cluster and start fresh
# =============================================================================
section "STEP 0: Fresh Kind Cluster"

if kind get clusters 2>/dev/null | grep -q "gitops-lab"; then
  warn "Deleting existing 'gitops-lab' cluster..."
  kind delete cluster --name gitops-lab
fi

info "Creating Kind cluster from kind-cluster.yaml..."
kind create cluster --config "${SCRIPT_DIR}/kind-cluster.yaml"
kubectl cluster-info --context kind-gitops-lab
success "Cluster ready."

# =============================================================================
# STEP 1 – Install ArgoCD
# =============================================================================
section "STEP 1: Install ArgoCD"

info "Creating argocd namespace..."
kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -

info "Applying ArgoCD install manifest..."
kubectl apply -n "${ARGOCD_NS}" \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

info "Waiting for ArgoCD server to be ready (this takes ~90s)..."
kubectl rollout status deployment/argocd-server -n "${ARGOCD_NS}" --timeout=180s
success "ArgoCD server is running."

# Patch argocd-server to use NodePort 30080 for UI access
info "Patching argocd-server service to NodePort ${ARGOCD_NODEPORT}..."
kubectl patch svc argocd-server -n "${ARGOCD_NS}" \
  -p "{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"port\":443,\"targetPort\":8080,\"nodePort\":${ARGOCD_NODEPORT},\"protocol\":\"TCP\",\"name\":\"https\"}]}}"
success "ArgoCD UI accessible at http://localhost:${ARGOCD_NODEPORT}"

# =============================================================================
# STEP 2 – Log in via ArgoCD CLI
# =============================================================================
section "STEP 2: ArgoCD CLI Login"

info "Retrieving initial admin password..."
ARGOCD_PASSWORD=$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "  Username: admin"
echo "  Password: ${ARGOCD_PASSWORD}"

info "Logging in to ArgoCD CLI..."
argocd login localhost:${ARGOCD_NODEPORT} \
  --username admin \
  --password "${ARGOCD_PASSWORD}" \
  --insecure
success "Logged in to ArgoCD."

# =============================================================================
# STEP 3 – Add Helm repo dependency and push chart (done manually before this)
#           Then create the ArgoCD Application
# =============================================================================
section "STEP 3: Create ArgoCD Application"

info "Applying ArgoCD Application manifest..."
kubectl apply -f "${SCRIPT_DIR}/argocd-app.yaml"
success "Application '${APP_NAME}' created in ArgoCD."

info "Waiting for ArgoCD to sync (auto-sync enabled)..."
argocd app wait "${APP_NAME}" \
  --sync \
  --health \
  --timeout 180
success "Application synced and healthy."

# =============================================================================
# STEP 4 – Verify deployment
# =============================================================================
section "STEP 4: Verify Deployment"

info "ArgoCD Application status:"
argocd app get "${APP_NAME}"

info "Pods in ${APP_NS} namespace:"
kubectl get pods -n "${APP_NS}" -o wide

info "Services in ${APP_NS} namespace:"
kubectl get svc -n "${APP_NS}"

success "AdGuard Home is accessible at http://localhost:30300"

# =============================================================================
# STEP 5 – Demonstrate auto-sync (instructions for manual step)
# =============================================================================
section "STEP 5: Auto-Sync Demo Instructions"

cat <<'EOF'

  --- GitOps Auto-Sync Demo ---

  To observe auto-sync, edit labs/week09-10/Deliverables/kunal/lab01/helm/adguard-home/values.yaml in your branch:
    1. Change replicas from 1 to 2:
         replicas: 2
    2. git add . && git commit -m "scale adguard to 2 replicas" && git push

  ArgoCD polls every 3 minutes by default. To force immediate sync:
    argocd app sync adguard-home

  Watch the sync happen:
    argocd app get adguard-home --watch

EOF

# =============================================================================
# STEP 6 – Demonstrate drift detection (selfHeal)
# =============================================================================
section "STEP 6: Drift Detection Demo"

info "Manually scaling deployment to 0 (simulating drift)..."
kubectl scale deployment -n "${APP_NS}" \
  -l "app.kubernetes.io/name=adguard-home" --replicas=0

info "Watching ArgoCD detect and reconcile drift (selfHeal=true)..."
echo "  Waiting up to 60s for reconciliation..."
sleep 10
argocd app get "${APP_NAME}"

info "Pods after reconciliation:"
kubectl get pods -n "${APP_NS}"

success "Drift reconciled — ArgoCD restored the desired state from Git."

# =============================================================================
# Summary
# =============================================================================
section "Lab 01 Complete"
echo ""
echo "  ArgoCD UI:       http://localhost:${ARGOCD_NODEPORT}"
echo "  AdGuard Home UI: http://localhost:30300"
echo "  ArgoCD user:     admin"
echo "  ArgoCD password: ${ARGOCD_PASSWORD}"
echo ""
echo "  Deliverables in this directory:"
echo "    argocd-app.yaml   – ArgoCD Application manifest"
echo "    lab01_notes.md    – GitOps workflow explanation"
echo "    lab01.txt         – Capture evidence by running: bash lab01.sh 2>&1 | tee lab01.txt"
echo ""
