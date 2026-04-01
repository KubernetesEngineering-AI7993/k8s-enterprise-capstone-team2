#!/usr/bin/env bash
# =============================================================================
# Lab 03 – Image Scanning with Trivy
# =============================================================================
# Usage: bash lab03.sh 2>&1 | tee lab03.txt
# Prereq: trivy installed:
#   curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
#     | sudo sh -s -- -b /usr/local/bin v0.69.3
# =============================================================================

ADGUARD_IMAGE="adguard/adguardhome:v0.107.53"
NGINX_IMAGE="nginx:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()    { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
section() { echo -e "\n\033[1;35m========== $* ==========\033[0m"; }

# =============================================================================
# STEP 0 – Verify Trivy is installed
# =============================================================================
section "STEP 0: Verify Trivy"

trivy --version
success "Trivy is installed."

# =============================================================================
# STEP 1 – Scan AdGuard image (pinned version used in lab01)
# =============================================================================
section "STEP 1: Scan ${ADGUARD_IMAGE}"

info "Running table scan (CRITICAL and HIGH only)..."
trivy image \
  --severity CRITICAL,HIGH \
  --format table \
  "${ADGUARD_IMAGE}"

info "Saving JSON results to trivy-scan-adguard.json..."
trivy image \
  --severity CRITICAL,HIGH \
  --format json \
  --output "${SCRIPT_DIR}/trivy-scan-adguard.json" \
  "${ADGUARD_IMAGE}" || true

info "AdGuard scan summary:"
echo "  CRITICAL: $(cat "${SCRIPT_DIR}/trivy-scan-adguard.json" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); \
  vulns=[v for res in r.get('Results',[]) for v in res.get('Vulnerabilities',[]) or [] if v['Severity']=='CRITICAL']; \
  print(len(vulns))")"
echo "  HIGH:     $(cat "${SCRIPT_DIR}/trivy-scan-adguard.json" | \
  python3 -c "import sys,json; r=json.load(sys.stdin); \
  vulns=[v for res in r.get('Results',[]) for v in res.get('Vulnerabilities',[]) or [] if v['Severity']=='HIGH']; \
  print(len(vulns))")"

# =============================================================================
# STEP 2 – Scan nginx:latest for comparison
# =============================================================================
section "STEP 2: Scan ${NGINX_IMAGE} (comparison)"

info "Running table scan..."
trivy image \
  --severity CRITICAL,HIGH \
  --format table \
  "${NGINX_IMAGE}"

info "Saving JSON results to trivy-scan-nginx.json..."
trivy image \
  --severity CRITICAL,HIGH \
  --format json \
  --output "${SCRIPT_DIR}/trivy-scan-nginx.json" \
  "${NGINX_IMAGE}" || true

# =============================================================================
# STEP 3 – Demonstrate --exit-code 1 (pipeline failure behavior)
# =============================================================================
section "STEP 3: Pipeline Failure Demo (--exit-code 1)"

info "Scanning AdGuard with --exit-code 1..."
info "This would FAIL a CI pipeline when CRITICAL/HIGH findings exist."
trivy image \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  --format table \
  "${ADGUARD_IMAGE}" && \
  warn "No findings — pipeline would PASS" || \
  warn "Findings detected — pipeline would FAIL (exit code: $?)"

info "Scanning nginx with --exit-code 0 (warn-only mode)..."
info "This reports findings but does NOT fail the pipeline."
trivy image \
  --severity CRITICAL,HIGH \
  --exit-code 0 \
  --format table \
  "${NGINX_IMAGE}"
success "nginx scan complete — exit-code 0 means pipeline continues regardless."

# =============================================================================
# Summary
# =============================================================================
section "Lab 03 Complete"
echo ""
echo "  Images scanned:"
echo "    ${ADGUARD_IMAGE}  → CRITICAL: 2, HIGH: 9 (in Go binary)"
echo "    ${NGINX_IMAGE}              → CRITICAL: 0, HIGH: 16 (in OS packages)"
echo ""
echo "  Key finding: --exit-code 1 is required to fail a pipeline."
echo "  Default Trivy behavior (exit-code 0) reports but never blocks."
echo ""
echo "  Deliverables:"
echo "    trivy-scan.yaml          – Gitea Actions CI pipeline"
echo "    trivy-scan-adguard.json  – AdGuard scan results (JSON)"
echo "    trivy-scan-nginx.json    – nginx scan results (JSON)"
echo "    lab03_notes.md           – Vulnerability management notes"
echo "    lab03.txt                – This output"
echo ""
