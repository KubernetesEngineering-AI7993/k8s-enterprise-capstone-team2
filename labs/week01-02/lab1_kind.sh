#!/bin/bash
# Create cluster
echo ""
echo "================================================"
echo "Creating Kubernetes cluster..."
echo "================================================"
kind create cluster --name test-k8s --config kind.yaml

# Get info
echo ""
echo "================================================"
echo "Cluster Information"
echo "================================================"
echo ""
echo "--- Nodes ---"
kubectl get nodes -o wide
echo ""
echo "--- Pods ---"
kubectl get pods -A -o wide
echo ""
echo "--- Cluster Info ---"
kubectl cluster-info
echo ""
echo "--- Context Info ---"
kubectl config get-contexts
echo ""
echo "--- Current Context ---"
kubectl config current-context
