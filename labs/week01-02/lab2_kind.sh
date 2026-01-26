# Apply namespaces
kubectl apply -f ./namespaces.yaml
sleep 2
kubectl get namespaces --show-labels
kubectl config current-context
kubectl config view --minify --output 'jsonpath={..namespace}' && echo ""
kubectl config set-context --current --namespace=dev
kubectl config view --minify --output 'jsonpath={..namespace}' && echo ""
# Deploy test pod
kubectl apply -f lab2.yaml
kubectl wait --for=condition=Ready pod/test-pod -n dev --timeout=60s
kubectl exec test-pod -n dev -- nginx -v
