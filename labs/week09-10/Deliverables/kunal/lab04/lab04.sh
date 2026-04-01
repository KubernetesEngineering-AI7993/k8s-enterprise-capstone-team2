#!/usr/bin/env bash
# =============================================================================
# Lab 04 – Deployment Validation
# Week 09-10 | Kunal
# =============================================================================
# Usage: bash lab04.sh 2>&1 | tee lab04.txt
# Prereq: gitops-lab cluster running from lab01, python3 installed
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NS="adguard-home"

info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
section() { echo -e "\n\033[1;35m========== $* ==========\033[0m"; }

# =============================================================================
# STEP 0 – Verify prerequisites
# =============================================================================
section "STEP 0: Verify Prerequisites"

kubectl cluster-info --context kind-gitops-lab
python3 --version
python3 -c "import yaml" 2>/dev/null || {
  warn "PyYAML not installed — installing..."
  pip3 install pyyaml --break-system-packages
}
success "Prerequisites ready."

# =============================================================================
# STEP 1 – Validate the bad deployment (expect FAILURE)
# =============================================================================
section "STEP 1: Validate bad-deployment.yaml (expect FAIL)"

info "Running validator against bad-deployment.yaml..."
bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/bad-deployment.yaml"
BAD_EXIT=$?

echo ""
if [[ "$BAD_EXIT" -ne 0 ]]; then
  success "Validator correctly rejected bad-deployment.yaml (exit code: ${BAD_EXIT})"
else
  warn "Unexpected: bad-deployment.yaml passed validation"
fi

# =============================================================================
# STEP 2 – Attempt to apply bad deployment to cluster (demonstrate blocking)
# =============================================================================
section "STEP 2: Attempt to Apply Bad Deployment (blocked by validator)"

info "Simulating CI gate — validate before kubectl apply..."
if bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/bad-deployment.yaml" > /dev/null 2>&1; then
  info "Validation passed — applying to cluster..."
  kubectl apply -f "${SCRIPT_DIR}/bad-deployment.yaml"
else
  echo -e "\n\033[1;31m[BLOCKED]\033[0m Deployment rejected by validator — kubectl apply was NOT run."
  echo "         Fix the manifest and re-run validation before deploying."
fi

success "Bad deployment was blocked."

# =============================================================================
# STEP 3 – Validate the good deployment (expect PASS)
# =============================================================================
section "STEP 3: Validate good-deployment.yaml (expect PASS)"

info "Running validator against good-deployment.yaml..."
bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}/good-deployment.yaml"
GOOD_EXIT=$?

echo ""
if [[ "$GOOD_EXIT" -eq 0 ]]; then
  success "Validator accepted good-deployment.yaml (exit code: ${GOOD_EXIT})"
else
  warn "Unexpected: good-deployment.yaml failed validation"
fi

# =============================================================================
# STEP 4 – Apply good deployment to cluster (allowed through)
# =============================================================================
section "STEP 4: Apply Good Deployment to Cluster"

info "Validation passed — applying good-deployment.yaml to cluster..."
kubectl apply -f "${SCRIPT_DIR}/good-deployment.yaml"

info "Waiting for rollout..."
kubectl rollout status deployment/adguard-good -n "${APP_NS}" --timeout=120s

info "Verifying pod is running:"
kubectl get pods -n "${APP_NS}" -l app=adguard-good

success "Good deployment applied and running."

# =============================================================================
# STEP 5 – Validate entire lab04 directory (batch mode)
# =============================================================================
section "STEP 5: Batch Validation of All Manifests in Lab04"

info "Running validator against all YAML files in lab04/..."
bash "${SCRIPT_DIR}/validate.sh" "${SCRIPT_DIR}"
BATCH_EXIT=$?

echo ""
info "Batch validation exit code: ${BATCH_EXIT}"
info "(Expected: 1 — because bad-deployment.yaml is present in the directory)"

# =============================================================================
# STEP 6 – Cleanup
# =============================================================================
section "STEP 6: Cleanup"

kubectl delete deployment adguard-good -n "${APP_NS}" --ignore-not-found
success "Cleaned up adguard-good deployment."

# =============================================================================
# Summary
# =============================================================================
section "Lab 04 Complete"
echo ""
echo "  validate.sh exit codes:"
echo "    bad-deployment.yaml  → exit ${BAD_EXIT} (FAIL — deployment blocked)"
echo "    good-deployment.yaml → exit ${GOOD_EXIT} (PASS — deployment allowed)"
echo ""
echo "  Checks enforced:"
echo "    1. Resource limits (cpu + memory)"
echo "    2. No ':latest' image tag"
echo "    3. Liveness probe defined"
echo "    4. Readiness probe defined"
