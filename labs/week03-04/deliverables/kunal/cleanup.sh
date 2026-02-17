# Cleanup script: removes Kubernetes resources created by week03-04 labs
set -euo pipefail

echo "=== Lab cleanup: deleting deployments ==="
for dep in resource-demo toleration-demo sample-app crashloop-demo imagepullback-demo pendingpod-demo pendingpods-demo selector-demo; do
  kubectl delete deployment "$dep" --ignore-not-found --timeout=30s
done

echo ""
echo "=== Deleting HPA (lab03) ==="
kubectl delete hpa sample-hpa --ignore-not-found

echo ""
echo "=== Deleting standalone pod (lab02 test-pod) ==="
kubectl delete pod test-pod --ignore-not-found --timeout=30s

echo ""
echo "=== Deleting services (lab04) ==="
kubectl delete service selector-demo-svc --ignore-not-found

echo ""
echo "=== Removing taint and label from node test-k8s-worker2 (lab02) ==="
kubectl taint nodes test-k8s-worker2 dedicated=ops:NoSchedule- --ignore-not-found 2>/dev/null || true
kubectl label nodes test-k8s-worker2 tainttest- --ignore-not-found 2>/dev/null || true

echo ""
echo "=== Waiting for resources to terminate... ==="
sleep 10

echo ""
echo "=== Cleanup complete ==="
kubectl get deployments 2>/dev/null || true
kubectl get pods 2>/dev/null || true
kubectl get hpa 2>/dev/null || true
kubectl get svc 2>/dev/null || true
