echo "=== Scenario 1: CrashLoopBackOff ==="
echo "--- Deploying failing workload (crashloop.yaml) ---"
kubectl apply -f ./crashloop.yaml
sleep 10
kubectl get pods
kubectl describe pod
kubectl delete deployment crashloop-demo

echo ""
echo "--- Deploying fixed workload (fixed-crashloop.yaml) ---"
kubectl delete deployment crashloop-demo --ignore-not-found
kubectl wait --for=delete deployment/crashloop-demo --timeout=60s 2>/dev/null || true
kubectl apply -f ./fixed-crashloop.yaml
kubectl wait --for=condition=available --timeout=60s deployment/crashloop-demo
kubectl get pods
kubectl describe pod
kubectl delete deployment crashloop-demo --ignore-not-found
kubectl wait --for=delete deployment/crashloop-demo --timeout=60s 2>/dev/null || true

echo ""
echo "=== Scenario 2: ImagePullBackOff ==="
echo "--- Deploying failing workload (imagepullback.yaml) ---"
kubectl apply -f ./imagepullback.yaml
sleep 15
kubectl get pods
kubectl describe pod
kubectl delete deployment imagepullback-demo

echo ""
echo "--- Deploying fixed workload (fixed-imagepullback.yaml) ---"
kubectl delete deployment imagepullback-demo --ignore-not-found
kubectl wait --for=delete deployment/imagepullback-demo --timeout=60s 2>/dev/null || true
kubectl apply -f ./fixed-imagepullback.yaml
kubectl wait --for=condition=available --timeout=60s deployment/imagepullback-demo
kubectl get pods
kubectl describe pod
kubectl delete deployment imagepullback-demo --ignore-not-found
kubectl wait --for=delete deployment/imagepullback-demo --timeout=60s 2>/dev/null || true

echo ""
echo "=== Scenario 3: Pending Pods ==="
echo "--- Deploying failing workload (pendingpod.yaml) ---"
kubectl apply -f ./pendingpod.yaml
sleep 5
kubectl get pods
kubectl describe pod
kubectl delete deployment pendingpod-demo --ignore-not-found

echo ""
echo "--- Deploying fixed workload (fixed-pendingpod.yaml) ---"
kubectl delete deployment pendingpod-demo --ignore-not-found
kubectl wait --for=delete deployment/pendingpod-demo --timeout=60s 2>/dev/null || true
kubectl apply -f ./fixed-pendingpod.yaml
kubectl wait --for=condition=available --timeout=60s deployment/pendingpod-demo
kubectl get pods
kubectl describe pod
kubectl delete deployment pendingpod-demo --ignore-not-found
kubectl wait --for=delete deployment/pendingpod-demo --timeout=60s 2>/dev/null || true

echo ""
echo "=== Scenario 4: Service selector mismatch ==="
echo "--- Deploying service with selector mismatch ---"
kubectl apply -f ./service-selector-mismatch.yaml
kubectl wait --for=condition=available --timeout=60s deployment/selector-demo
sleep 3
kubectl describe service selector-demo
kubectl get endpointslice -l kubernetes.io/service-name=selector-demo-svc
kubectl delete -f ./service-selector-mismatch.yaml

echo ""
echo "--- Deploying fixed service (fixed-service-selector-mismatch.yaml) ---"
kubectl apply -f ./fixed-service-selector-mismatch.yaml
kubectl wait --for=condition=available --timeout=60s deployment/selector-demo
sleep 3
kubectl describe service selector-demo
kubectl get endpointslice -l kubernetes.io/service-name=selector-demo-svc
kubectl delete -f ./fixed-service-selector-mismatch.yaml
