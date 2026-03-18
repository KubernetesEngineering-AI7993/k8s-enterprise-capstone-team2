set -euo pipefail

echo "=== Lab cleanup: week07-08 (kunal) ==="

echo ""
echo "--- Uninstall Helm release sample-app (lab01) ---"
helm uninstall sample-app --ignore-not-found 2>/dev/null || true

echo ""
echo "--- Delete lab02 multi-container Pod ---"
kubectl delete pod sidecar-demo --ignore-not-found --grace-period=0 --force --wait=false || true

echo ""
echo "--- Delete lab04 Deployment (rolling-demo) ---"
kubectl delete deployment rolling-demo --ignore-not-found --timeout=30s || true

echo ""
echo "--- Waiting for resources to terminate... ---"
sleep 5

echo ""
echo "--- Cleanup complete (week07-08) ==="
helm list 2>/dev/null || true
kubectl get pods 2>/dev/null || true
kubectl get deployments 2>/dev/null || true
kubectl get svc 2>/dev/null || true
