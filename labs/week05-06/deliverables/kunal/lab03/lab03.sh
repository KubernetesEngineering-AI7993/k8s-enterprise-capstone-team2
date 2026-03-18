set -euo pipefail

DEPLOYMENT_LABEL="app=app-probes"

echo "=== Lab 03 – Liveness & Readiness Probes ==="

echo ""
echo "--- Step 1: Start deployment with NO probes (deployment-no-probes.yaml) ---"
kubectl apply -f ./deployment-no-probes.yaml

echo ""
echo "--- Waiting for pods to start ---"
sleep 15
kubectl get pods -l "${DEPLOYMENT_LABEL}" -o wide

echo ""
echo "--- Pod details (no probe configuration yet) ---"
kubectl describe pods -l "${DEPLOYMENT_LABEL}"

echo ""
echo "--- Step 2: Add liveness probe (add_liveness.yaml) ---"
kubectl apply -f ./add_liveness.yaml

echo ""
echo "--- Waiting for liveness probe to take effect ---"
sleep 15
kubectl get pods -l "${DEPLOYMENT_LABEL}" -o wide

echo ""
echo "--- Pod details (liveness probe configured) ---"
kubectl describe pods -l "${DEPLOYMENT_LABEL}"

echo ""
echo "--- Step 3: Add readiness probe (add_readiness.yaml) ---"
kubectl apply -f ./add_readiness.yaml

echo ""
echo "--- Waiting for readiness probe to take effect ---"
sleep 15
kubectl get pods -l "${DEPLOYMENT_LABEL}" -o wide

echo ""
echo "--- Pod details (liveness+readiness configured) ---"
kubectl describe pods -l "${DEPLOYMENT_LABEL}"

echo ""
echo "--- Step 4: Break liveness+readiness probes (add_liveness_with_failure.yaml) ---"
kubectl apply -f ./add_liveness_with_failure.yaml

echo ""
echo "--- Waiting for liveness-driven restarts ---"
sleep 40
kubectl get pods -l "${DEPLOYMENT_LABEL}" -o wide

echo ""
echo "--- Pod details (probe failures should appear) ---"
kubectl describe pods -l "${DEPLOYMENT_LABEL}"

echo ""
echo "--- Step 5: Fix probes (re-apply add_readiness.yaml for healthy liveness+readiness) ---"
kubectl apply -f ./add_readiness.yaml

echo ""
echo "--- Waiting for probes to recover ---"
sleep 15
kubectl get pods -l "${DEPLOYMENT_LABEL}" -o wide

echo ""
echo "--- Final pod status ---"
kubectl get pods -l "${DEPLOYMENT_LABEL}"

