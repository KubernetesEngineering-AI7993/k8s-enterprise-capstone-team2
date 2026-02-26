#!/bin/bash
echo "=== Initial state ==="
sudo kubectl get deployments
sudo kubectl get pods
sudo kubectl get services
echo "=== Deploy Nginx pods ==="
sudo kubectl apply -f deployment.yaml
echo "=== Inspect deployment and pods ==="
sudo kubectl get deployments
sudo kubectl describe deployment app-demo
sudo kubectl get pods
sudo kubectl describe pod app-demo-689949785f-6w7pg
echo "=== Deploy service ==="
sudo kubectl apply -f service.yaml
echo "=== Inspect service ==="
sudo kubectl get services
sudo kubectl describe service app-demo
echo "=== Scale replica pods ==="
sudo kubectl apply -f deployment-scaled.yaml
sudo kubectl get deployments
sudo kubectl get pods
echo "=== Test traffic flow ==="
sudo kubectl run curl-test --image=curlimages/curl -it --rm --restart=Never -- http://app-demo