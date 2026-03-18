set -euo pipefail

POD_NAME="sidecar-demo"

echo "=== Lab 02 – Multi-Container Pods ==="

echo ""
echo "--- Applying multi-container Pod (multi-container.yaml) ---"
kubectl apply -f ./multi-container.yaml

echo ""
echo "--- Waiting for Pod to be Ready ---"
kubectl wait --for=condition=Ready pod/"$POD_NAME" --timeout=120s

echo ""
echo "--- Pod status ---"
kubectl get pod "$POD_NAME" -o wide

echo ""
echo "--- Pod details (containers and shared volume) ---"
kubectl describe pod "$POD_NAME" | head -80

echo ""
echo "--- Sidecar writes to shared volume; app serves it. Waiting a few seconds for sidecar to write ---"
sleep 8

echo ""
echo "--- Curl main app (nginx serves /usr/share/nginx/html = same volume as sidecar /data) ---"
kubectl exec "$POD_NAME" -c app -- curl -s http://localhost:80/ | head -20

echo ""
echo "--- Sidecar logs ---"
kubectl logs "$POD_NAME" -c sidecar --tail=5

echo ""
echo "--- List shared volume from both containers ---"
echo "app (nginx):"
kubectl exec "$POD_NAME" -c app -- ls -la /usr/share/nginx/html 2>/dev/null || true
echo "sidecar:"
kubectl exec "$POD_NAME" -c sidecar -- ls -la /data 2>/dev/null || true
