echo "=== Verify Metrics Server (kube-system) ==="
kubectl get deployment metrics-server -n kube-system

echo ""
echo "=== Current resource usage: top nodes ==="
kubectl top nodes

echo ""
echo "=== Current resource usage: top pods ==="
kubectl top pods

echo ""
echo "=== Deploying sample app (sample.yaml) ==="
kubectl apply -f ./sample.yaml
kubectl wait --for=condition=available --timeout=60s deployment/sample-app

echo ""
echo "=== Pods ==="
kubectl get pods

echo ""
echo "=== Creating HPA (hpa.yaml) ==="
kubectl apply -f ./hpa.yaml
sleep 3

echo ""
echo "=== HPA status ==="
kubectl get hpa

echo ""
echo "=== HPA details: sample-hpa ==="
kubectl describe hpa sample-hpa

echo ""
echo "=== Generating load in pod ==="
kubectl wait --for=condition=ready pod -l app=sample-app --timeout=60s
kubectl exec $(kubectl get pod -l app=sample-app -o jsonpath='{.items[0].metadata.name}') -- /bin/sh -c 'end=$(($(date +%s) + 90)); while [ $(date +%s) -lt $end ]; do :; done'

echo ""
echo "=== Events (sorted by timestamp) ==="
kubectl get events --sort-by='.lastTimestamp'
