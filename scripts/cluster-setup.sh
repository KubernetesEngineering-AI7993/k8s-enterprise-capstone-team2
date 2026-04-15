#!/usr/bin/env bash
# cluster-setup.sh
# Full bootstrap for the warehouse-cv platform.
# Run once against a fresh cluster. Idempotent on re-runs.
# See docs/cluster-setup.md for step-by-step explanations.

set -euo pipefail

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ─── Configuration (override via env) ────────────────────────────────────────
REPO_URL="${REPO_URL:-https://github.com/example-org/k8s-enterprise-capstone-team2.git}"
TARGET_BRANCH="${TARGET_BRANCH:-mlops}"
APP_NAMESPACE="${APP_NAMESPACE:-warehouse-cv}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-9.5.0}"
ARGOCD_IMAGE_TAG="${ARGOCD_IMAGE_TAG:-v3.3.6}"
SEALED_SECRETS_VERSION="${SEALED_SECRETS_VERSION:-2.18.4}"
PROM_STACK_VERSION="${PROM_STACK_VERSION:-82.4.0}"
INGRESS_NGINX_VERSION="${INGRESS_NGINX_VERSION:-4.15.1}"
CREATE_KIND_IF_MISSING="${CREATE_KIND_IF_MISSING:-true}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-warehouse-cv}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
KIND_CONFIG_FILE="${KIND_CONFIG_FILE:-${REPO_ROOT}/k8s/kind/kind.yaml}"
CURRENT_CONTEXT=""
IS_KIND_CLUSTER="false"

# ─── Kind bootstrap (optional) ────────────────────────────────────────────────
create_kind_cluster() {
  command -v kind &>/dev/null || die "No kube context is set and 'kind' is not installed.\nInstall kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
  [[ -f "${KIND_CONFIG_FILE}" ]] || die "Kind config not found at '${KIND_CONFIG_FILE}'."

  info "No kube context found. Creating a local kind cluster..."
  info "  Name          : ${KIND_CLUSTER_NAME}"
  info "  Config file   : ${KIND_CONFIG_FILE}"

  if kind get clusters | rg -x "${KIND_CLUSTER_NAME}" &>/dev/null; then
    warn "kind cluster '${KIND_CLUSTER_NAME}' already exists; reusing it."
  else
    kind create cluster --name "${KIND_CLUSTER_NAME}" --config "${KIND_CONFIG_FILE}" --wait 180s
  fi

  kubectl config use-context "kind-${KIND_CLUSTER_NAME}" >/dev/null
  CURRENT_CONTEXT="kind-${KIND_CLUSTER_NAME}"
  IS_KIND_CLUSTER="true"
  success "kind cluster ready and selected: ${CURRENT_CONTEXT}"
}

# ─── 0. Pre-flight checks ────────────────────────────────────────────────────
preflight() {
  info "Running pre-flight checks..."

  local missing=()
  for cmd in kubectl helm kubeseal; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}\n\nInstall guide:\n  kubectl  : https://kubernetes.io/docs/tasks/tools/\n  helm     : https://helm.sh/docs/intro/install/\n  kubeseal : https://github.com/bitnami-labs/sealed-secrets#installation"
  fi

  CURRENT_CONTEXT="$(kubectl config current-context 2>/dev/null || true)"
  if [[ -z "${CURRENT_CONTEXT}" ]]; then
    if [[ "${CREATE_KIND_IF_MISSING}" == "true" ]]; then
      create_kind_cluster
    else
      die "No current kube context is set.\n\nSet one first, for example:\n  # If this host is the control-plane node\n  export KUBECONFIG=/etc/kubernetes/admin.conf\n\n  # Or copy an admin kubeconfig to this machine\n  mkdir -p ~/.kube && cp <admin-kubeconfig> ~/.kube/config\n\nThen verify:\n  kubectl config get-contexts\n  kubectl config use-context <context-name>\n  kubectl cluster-info\n\nOr rerun with CREATE_KIND_IF_MISSING=true to auto-create a local kind cluster."
    fi
  else
    if [[ "${CURRENT_CONTEXT}" == kind-* ]]; then
      IS_KIND_CLUSTER="true"
    fi
  fi

  kubectl cluster-info &>/dev/null \
    || die "Cannot reach the cluster for context '${CURRENT_CONTEXT}'.\nCheck kubeconfig credentials, API endpoint, and network."

  success "Pre-flight checks passed."
  echo
  info "  Cluster : $(kubectl config current-context)"
  info "  Kind    : ${IS_KIND_CLUSTER}"
  info "  Repo    : ${REPO_URL} @ ${TARGET_BRANCH}"
  echo
  read -r -p "$(echo -e "${BOLD}Continue? [y/N]${RESET} ")" confirm
  [[ "${confirm,,}" == "y" ]] || { info "Aborted."; exit 0; }
}

# ─── 1. Helm repos ───────────────────────────────────────────────────────────
add_helm_repos() {
  info "Adding Helm repos..."
  helm repo add sealed-secrets   https://bitnami-labs.github.io/sealed-secrets       --force-update
  helm repo add argo             https://argoproj.github.io/argo-helm                --force-update
  helm repo add ingress-nginx    https://kubernetes.github.io/ingress-nginx           --force-update
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  helm repo update
  success "Helm repos up to date."
}

# ─── 2. Sealed Secrets controller ────────────────────────────────────────────
install_sealed_secrets() {
  info "Installing Sealed Secrets controller (${SEALED_SECRETS_VERSION})..."
  helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
    --namespace kube-system \
    --version "${SEALED_SECRETS_VERSION}" \
    --set fullnameOverride=sealed-secrets \
    --wait
  success "Sealed Secrets controller ready."
}

# ─── 3. Seal credentials ─────────────────────────────────────────────────────
seal_secret() {
  local sealed_file="${REPO_ROOT}/k8s/base/sealed-secret.yaml"

  if grep -q "PLACEHOLDER_SEAL_WITH_KUBESEAL" "${sealed_file}" 2>/dev/null; then
    warn "sealed-secret.yaml still contains placeholder values."
    warn "You must seal real credentials before Argo CD can create the Secret."
    echo
    echo -e "  Run the following and commit the result:\n"
    echo -e "    kubectl create secret generic warehouse-cv-secret \\"
    echo -e "      --namespace ${APP_NAMESPACE} \\"
    echo -e "      --from-literal=OBJECT_STORE_ACCESS_KEY=<your-key> \\"
    echo -e "      --from-literal=OBJECT_STORE_SECRET_KEY=<your-secret> \\"
    echo -e "      --dry-run=client -o yaml \\"
    echo -e "    | kubeseal \\"
    echo -e "        --controller-namespace kube-system \\"
    echo -e "        --controller-name sealed-secrets \\"
    echo -e "        --format yaml \\"
    echo -e "    > k8s/base/sealed-secret.yaml"
    echo
    read -r -p "$(echo -e "${BOLD}Seal now interactively? [y/N]${RESET} ")" do_seal
    if [[ "${do_seal,,}" == "y" ]]; then
      read -r -s -p "OBJECT_STORE_ACCESS_KEY: " access_key; echo
      read -r -s -p "OBJECT_STORE_SECRET_KEY: " secret_key; echo
      kubectl create secret generic warehouse-cv-secret \
        --namespace "${APP_NAMESPACE}" \
        --from-literal=OBJECT_STORE_ACCESS_KEY="${access_key}" \
        --from-literal=OBJECT_STORE_SECRET_KEY="${secret_key}" \
        --dry-run=client -o yaml \
      | kubeseal \
          --controller-namespace kube-system \
          --controller-name sealed-secrets \
          --format yaml \
      > "${sealed_file}"
      success "Credentials sealed → ${sealed_file}"
      warn "Commit and push ${sealed_file} to ${TARGET_BRANCH} before syncing Argo CD."
    else
      warn "Skipping credential sealing. Argo CD sync will fail until this is done."
    fi
  else
    success "sealed-secret.yaml already contains encrypted values."
  fi
}

# ─── 4. Argo CD ──────────────────────────────────────────────────────────────
install_argocd() {
  info "Installing Argo CD (chart ${ARGOCD_CHART_VERSION}, image ${ARGOCD_IMAGE_TAG})..."
  kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install argocd argo/argo-cd \
    --namespace "${ARGOCD_NAMESPACE}" \
    --version "${ARGOCD_CHART_VERSION}" \
    --set global.image.tag="${ARGOCD_IMAGE_TAG}" \
    --set server.service.type=ClusterIP \
    --wait
  success "Argo CD ready."
}

# ─── 5. Apply GitOps manifests ───────────────────────────────────────────────
apply_gitops() {
  info "Applying Argo CD AppProject and Application..."

  # Patch repoURL if it still points at the example placeholder
  local app_file="${REPO_ROOT}/gitops/argocd/warehouse-cv-dev-application.yaml"
  if grep -q "example-org" "${app_file}"; then
    warn "repoURL in ${app_file} is still the example placeholder."
    warn "Update it to your real remote before Argo CD can pull manifests."
    warn "  Continuing — apply will succeed but sync will fail until fixed."
  fi

  kubectl apply -f "${REPO_ROOT}/gitops/argocd/warehouse-cv-project.yaml"
  kubectl apply -f "${app_file}"
  success "GitOps manifests applied. Argo CD will begin syncing."
}

# ─── 6. NGINX Ingress Controller ─────────────────────────────────────────────
install_ingress_nginx() {
  info "Installing ingress-nginx (${INGRESS_NGINX_VERSION})..."
  if [[ "${IS_KIND_CLUSTER}" == "true" ]]; then
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      --create-namespace \
      --version "${INGRESS_NGINX_VERSION}" \
      --set controller.service.type=NodePort \
      --set controller.service.nodePorts.http=30080 \
      --set controller.service.nodePorts.https=30443 \
      --wait
  else
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      --create-namespace \
      --version "${INGRESS_NGINX_VERSION}" \
      --set controller.service.type=LoadBalancer \
      --wait
  fi
  success "ingress-nginx ready."
}

# ─── 7. kube-prometheus-stack (Prometheus + Grafana) ─────────────────────────
install_monitoring() {
  info "Installing kube-prometheus-stack (${PROM_STACK_VERSION})..."
  kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --version "${PROM_STACK_VERSION}" \
    --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
    --set grafana.sidecar.dashboards.enabled=true \
    --set grafana.sidecar.dashboards.searchNamespace=ALL \
    --wait
  success "kube-prometheus-stack ready."

  info "Applying ServiceMonitor and Grafana dashboard..."
  kubectl create namespace "${APP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f "${REPO_ROOT}/monitoring/prometheus/servicemonitor.yaml"
  kubectl apply -f "${REPO_ROOT}/monitoring/grafana/warehouse-cv-overview-dashboard-configmap.yaml"
  success "Monitoring resources applied."
}

# ─── 8. System ingress (Argo CD + Prometheus + Grafana) ──────────────────────
apply_system_ingress() {
  info "Applying ingress resources for Argo CD and monitoring..."
  kubectl apply -f "${REPO_ROOT}/k8s/system-ingress.yaml"
  success "System ingress resources applied."
}

# ─── 9. Wait for Argo CD sync ────────────────────────────────────────────────
wait_for_sync() {
  info "Waiting for Argo CD to sync warehouse-cv-dev (up to 30 sec)..."
  local timeout_seconds=30
  local poll_seconds=5
  local elapsed=0

  while (( elapsed < timeout_seconds )); do
    local sync_status
    local health_status
    sync_status="$(kubectl -n "${ARGOCD_NAMESPACE}" get app warehouse-cv-dev -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health_status="$(kubectl -n "${ARGOCD_NAMESPACE}" get app warehouse-cv-dev -o jsonpath='{.status.health.status}' 2>/dev/null || true)"

    if [[ "${sync_status}" == "Synced" && "${health_status}" == "Healthy" ]]; then
      success "Argo CD app is Synced and Healthy."
      return 0
    fi

    sleep "${poll_seconds}"
    elapsed=$((elapsed + poll_seconds))
  done

  warn "Argo CD sync timed out. Check:"
  warn "  kubectl -n ${ARGOCD_NAMESPACE} get app warehouse-cv-dev"
  warn "  kubectl -n ${ARGOCD_NAMESPACE} describe app warehouse-cv-dev"
}

# ─── 10. Summary ─────────────────────────────────────────────────────────────
print_summary() {
  echo
  echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
  echo -e "${GREEN}${BOLD}  Cluster bootstrap complete!${RESET}"
  echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
  echo

  local argocd_pass
  argocd_pass=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "<retrieve manually>")

  echo -e "  ${BOLD}Argo CD${RESET}"
  echo "    Port-forward : kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443"
  echo "    URL          : https://localhost:8080"
  echo "    Username     : admin"
  echo "    Password     : ${argocd_pass}"
  echo

  echo -e "  ${BOLD}Grafana${RESET}"
  echo "    Port-forward : kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
  echo "    URL          : http://localhost:3000"
  echo "    Username     : admin"
  echo "    Password     : prom-operator"
  echo

  echo -e "  ${BOLD}Application namespace${RESET}"
  echo "    kubectl get all -n ${APP_NAMESPACE}"
  echo

  echo -e "  ${BOLD}Ingress hosts (add to /etc/hosts pointing at ingress LoadBalancer IP)${RESET}"
  if [[ "${IS_KIND_CLUSTER}" == "true" ]]; then
    echo "    127.0.0.1 intake.warehouse-cv.internal"
    echo "    127.0.0.1 inference.warehouse-cv.internal"
    echo "    127.0.0.1 dashboard.warehouse-cv.internal"
    echo "    127.0.0.1 argocd.warehouse-cv.internal"
    echo "    127.0.0.1 prometheus.warehouse-cv.internal"
    echo "    127.0.0.1 grafana.warehouse-cv.internal"
  else
    echo "    intake.warehouse-cv.internal"
    echo "    inference.warehouse-cv.internal"
    echo "    dashboard.warehouse-cv.internal"
    echo "    argocd.warehouse-cv.internal"
    echo "    prometheus.warehouse-cv.internal"
    echo "    grafana.warehouse-cv.internal"
  fi
  echo
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo -e "\n${BOLD}warehouse-cv cluster bootstrap${RESET}\n"

  preflight
  add_helm_repos
  install_sealed_secrets
  seal_secret
  install_argocd
  apply_gitops
  install_ingress_nginx
  install_monitoring
  apply_system_ingress
  wait_for_sync
  print_summary
}

main "$@"
