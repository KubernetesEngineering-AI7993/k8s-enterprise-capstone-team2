#!/usr/bin/env bash
# =============================================================================
# Lab 02 – Secrets Management
# =============================================================================
# Usage: bash lab02.sh 2>&1 | tee lab02.txt
# Prereq: gitops-lab cluster running from lab01
# =============================================================================

APP_NS="adguard-home"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
section() { echo -e "\n\033[1;35m========== $* ==========\033[0m"; }

# =============================================================================
# STEP 0 – Verify cluster is running
# =============================================================================
section "STEP 0: Verify Cluster"

kubectl cluster-info --context kind-gitops-lab
kubectl get nodes
success "Cluster is ready."

# =============================================================================
# STEP 1 – Create secrets
# =============================================================================
section "STEP 1: Create Secrets"

info "Method A – kubectl imperative command (equivalent to secret-generic.yaml):"
kubectl create secret generic adguard-credentials-imperative \
  --from-literal=admin-username=admin \
  --from-literal=admin-password=changeme123 \
  --from-literal=upstream-dns-token=fake-dns-token-abc123 \
  -n "${APP_NS}" \
  --dry-run=client -o yaml

info "Method B – applying YAML manifest (declarative):"
kubectl apply -f "${SCRIPT_DIR}/secret-generic.yaml"
kubectl apply -f "${SCRIPT_DIR}/secret-tls.yaml"
success "Secrets created."

# =============================================================================
# STEP 2 – Inspect secrets (safely)
# =============================================================================
section "STEP 2: Inspect Secrets"

info "Listing secrets in ${APP_NS}:"
kubectl get secrets -n "${APP_NS}"

info "Describing adguard-credentials (no values shown):"
kubectl describe secret adguard-credentials -n "${APP_NS}"

info "Decoding a value to verify (admin-username only):"
kubectl get secret adguard-credentials -n "${APP_NS}" \
  -o jsonpath='{.data.admin-username}' | base64 -d
echo ""

success "Secrets verified."

# =============================================================================
# STEP 3 – Inject via environment variables
# =============================================================================
section "STEP 3: Secret Injection – Environment Variables"

info "Applying pod-env.yaml..."
# Delete if exists from a previous run
kubectl delete pod adguard-secret-env-demo -n "${APP_NS}" --ignore-not-found

kubectl apply -f "${SCRIPT_DIR}/pod-env.yaml"

info "Waiting for pod to complete..."
kubectl wait pod/adguard-secret-env-demo \
  -n "${APP_NS}" \
  --for=condition=Ready \
  --timeout=60s || true
sleep 5

info "Pod logs (evidence of env var injection):"
kubectl logs adguard-secret-env-demo -n "${APP_NS}"

info "Confirming env vars visible in pod describe (security consideration):"
kubectl describe pod adguard-secret-env-demo -n "${APP_NS}" \
  | grep -A3 "Environment:"

success "Environment variable injection demonstrated."

# =============================================================================
# STEP 4 – Inject via mounted volume
# =============================================================================
section "STEP 4: Secret Injection – Mounted Volume"

info "Applying pod-volume.yaml..."
kubectl delete pod adguard-secret-vol-demo -n "${APP_NS}" --ignore-not-found

kubectl apply -f "${SCRIPT_DIR}/pod-volume.yaml"

info "Waiting for pod to complete..."
kubectl wait pod/adguard-secret-vol-demo \
  -n "${APP_NS}" \
  --for=condition=Ready \
  --timeout=60s || true
sleep 5

info "Pod logs (evidence of volume mount injection):"
kubectl logs adguard-secret-vol-demo -n "${APP_NS}"

info "Confirming mount in pod describe:"
kubectl describe pod adguard-secret-vol-demo -n "${APP_NS}" \
  | grep -A5 "Mounts:"

success "Volume mount injection demonstrated."

# =============================================================================
# STEP 5 – Cleanup demo pods (keep secrets for reference)
# =============================================================================
section "STEP 5: Cleanup Demo Pods"

kubectl delete pod adguard-secret-env-demo -n "${APP_NS}" --ignore-not-found
kubectl delete pod adguard-secret-vol-demo -n "${APP_NS}" --ignore-not-found
kubectl delete secret adguard-credentials-imperative -n "${APP_NS}" --ignore-not-found

info "Remaining secrets:"
kubectl get secrets -n "${APP_NS}"

success "Cleanup complete. Secrets adguard-credentials and adguard-tls retained."

# =============================================================================
# Summary
# =============================================================================
section "Lab 02 Complete"
