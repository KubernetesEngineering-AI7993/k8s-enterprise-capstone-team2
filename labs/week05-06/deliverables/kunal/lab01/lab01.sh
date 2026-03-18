set -euo pipefail

DEPLOYMENT_NAME="app-demo"
SERVICE_NAME="app-demo"

echo "=== Lab 01 – Deployments & Services ==="

echo ""
echo "--- Applying Deployment (deployment.yaml) ---"
kubectl apply -f ./deployment.yaml

echo ""
echo "--- Applying Service (service.yaml) ---"
kubectl apply -f ./service.yaml

echo ""
echo "--- Waiting for Deployment to be available ---"
kubectl wait --for=condition=available --timeout=120s deployment/"$DEPLOYMENT_NAME"

echo ""
echo "--- Deployments ---"
kubectl get deployments

echo ""
echo "--- Services ---"
kubectl get services

echo ""
echo "--- Checking Service endpoints (traffic routing) ---"
kubectl get endpoints "$SERVICE_NAME" -o wide

echo ""
echo "--- Testing traffic flow via Service (curl) ---"
kubectl delete pod curl-client --ignore-not-found --timeout=30s
kubectl run curl-client --restart=Never --image=curlimages/curl:8.7.1 --labels app=curl-client --command -- sh -c "sleep 300" >/dev/null
kubectl wait --for=condition=Ready pod/curl-client --timeout=60s
kubectl exec curl-client -- sh -c "curl -sS http://$SERVICE_NAME/ | head -n 3"

echo ""
echo "--- Scaling Deployment to 3 replicas ---"
kubectl scale deployment/"$DEPLOYMENT_NAME" --replicas=3
kubectl rollout status deployment/"$DEPLOYMENT_NAME" --timeout=120s

echo ""
echo "--- Deployments after scale ---"
kubectl get deployments

echo ""
echo "--- Re-testing traffic flow via Service after scale (curl) ---"
kubectl exec curl-client -- sh -c "curl -sS http://$SERVICE_NAME/ | head -n 3"

echo ""
echo "--- Cleanup temporary curl client pod ---"
kubectl delete pod curl-client --ignore-not-found --timeout=60s

