#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Lab 02 - NetworkPolicies ==="
echo "Applying test workloads..."
kubectl apply -f "$LAB_DIR/networkpolicy-test-workloads.yaml"

echo "Waiting for test pods to become ready..."
kubectl wait --for=condition=Available deployment/backend -n dev --timeout=180s
kubectl wait --for=condition=Available deployment/frontend -n dev --timeout=180s
kubectl wait --for=condition=Available deployment/intruder -n dev --timeout=180s
kubectl wait --for=condition=Available deployment/qa-client -n qa --timeout=180s

FRONTEND_POD="$(kubectl get pod -n dev -l app=frontend -o jsonpath='{.items[0].metadata.name}')"
INTRUDER_POD="$(kubectl get pod -n dev -l app=intruder -o jsonpath='{.items[0].metadata.name}')"
QA_POD="$(kubectl get pod -n qa -l app=qa-client -o jsonpath='{.items[0].metadata.name}')"

echo "Applying default deny policy..."
kubectl apply -f "$LAB_DIR/default-deny.yaml"

echo "Applying policy to allow frontend -> backend:8080..."
kubectl apply -f "$LAB_DIR/allow-frontend-backend.yaml"

echo "=== Connectivity checks ==="
echo "1) frontend (allowed): expected HTTP 200"
kubectl exec -n dev "$FRONTEND_POD" -- \
  curl -sS -m 5 -o /dev/null -w "%{http_code}\n" http://backend.dev.svc.cluster.local:8080

echo "2) intruder (blocked): expected timeout/non-200"
kubectl exec -n dev "$INTRUDER_POD" -- \
  sh -c 'curl -sS -m 5 -o /dev/null -w "%{http_code}\n" http://backend.dev.svc.cluster.local:8080 || true'

echo "3) qa namespace client (blocked): expected timeout/non-200"
kubectl exec -n qa "$QA_POD" -- \
  sh -c 'curl -sS -m 5 -o /dev/null -w "%{http_code}\n" http://backend.dev.svc.cluster.local:8080 || true'

echo "Current network policies in dev:"
kubectl get networkpolicy -n dev
