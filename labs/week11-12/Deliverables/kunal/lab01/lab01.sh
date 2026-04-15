#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="dev"

echo "=== Lab 01 - RBAC & ServiceAccounts ==="
echo "Applying namespace and Frigate stack manifests..."
kubectl apply -f "$LAB_DIR/frigate-stack.yaml"

echo "Applying ServiceAccount + Role + RoleBinding..."
kubectl apply -f "$LAB_DIR/serviceaccount.yaml"
kubectl apply -f "$LAB_DIR/readonly-role.yaml"
kubectl apply -f "$LAB_DIR/readonly-rolebinding.yaml"

echo "Installing/ensuring nginx ingress controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443

echo "Waiting for Frigate deployment rollout (will stay pending if no GPU=true node exists)..."
kubectl rollout status deployment/frigate -n "$NAMESPACE" --timeout=180s || true

echo "RBAC verification checks..."
echo "Can readonly-app-sa list pods?"
kubectl auth can-i list pods -n "$NAMESPACE" --as "system:serviceaccount:$NAMESPACE:readonly-app-sa"
echo "Can readonly-app-sa delete pods? (should be no)"
kubectl auth can-i delete pods -n "$NAMESPACE" --as "system:serviceaccount:$NAMESPACE:readonly-app-sa" || true

echo "Current resources:"
kubectl get pods,svc,ingress -n "$NAMESPACE"

cat <<'EOF'

If Frigate is pending, label at least one node with:
  kubectl label node <node-name> GPU=true

Then re-check:
  kubectl get pods -n dev -o wide

To reach the UI locally from any device on your LAN:
  curl http://<k8s-node-ip>:30080

Optional host-based access:
  echo "<k8s-node-ip> nvr.internal" | sudo tee -a /etc/hosts
  curl -H "Host: nvr.internal" http://<k8s-node-ip>:30080
EOF
