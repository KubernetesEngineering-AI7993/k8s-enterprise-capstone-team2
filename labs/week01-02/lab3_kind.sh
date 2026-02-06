#!/bin/bash
# Set to dev namespace
kubectl config set-context --current --namespace=dev
# Apply configmap and service
kubectl apply -f ./nginx-service.yaml
# Apply deployment
kubectl apply -f ./nginx-deploy.yaml
# Make sure deployment is complete
kubectl rollout status deployment/nginx-deployment -n dev --timeout=120s
# Deployment Details
echo ""
echo "--- Deployment ---"
kubectl get deployment nginx-deployment -n dev -o wide

echo ""
echo "--- ReplicaSet ---"
kubectl get rs -n dev -l app=nginx

echo ""
echo "--- Pods ---"
kubectl get pods -n dev -l app=nginx -o wide

echo ""
echo "--- Services ---"
kubectl get svc -n dev -l app=nginx

echo ""
echo "========================================="
echo "Testing Application Access"
echo "========================================="

# Get a pod name
POD_NAME=$(kubectl get pods -n dev -l app=nginx -o jsonpath='{.items[0].metadata.name}')
echo ""
echo "Testing pod: $POD_NAME"

# Test direct pod access
echo ""
echo "--- Direct Pod Access Test ---"
kubectl exec $POD_NAME -n dev -- curl -s localhost | grep -o "<title>.*</title>"

# Test ClusterIP service
echo ""
echo "--- ClusterIP Service Test ---"
kubectl run curl-test --image=curlimages/curl:latest --rm -i --restart=Never -n dev -- \
  curl -s nginx-service.dev.svc.cluster.local | grep -o "<title>.*</title>"

echo ""
echo "========================================="
echo "Port Forward Setup"
echo "========================================="

echo ""
echo "Starting port-forward in background..."
kubectl port-forward -n dev --address 0.0.0.0 service/nginx-service 8080:80 > /tmp/port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
echo "Port-forward running on PID: $PORT_FORWARD_PID"
echo "Local access: http://localhost:8080"

# Wait for port-forward to be ready
sleep 3

echo ""
echo "Testing local access..."
curl -s http://localhost:8080 
echo ""
echo "========================================="
echo "NodePort Access (kind-specific)"
echo "========================================="
echo ""
echo "NodePort service accessible at: http://localhost:30080"
echo "Testing NodePort access..."
curl -s http://localhost:30080
