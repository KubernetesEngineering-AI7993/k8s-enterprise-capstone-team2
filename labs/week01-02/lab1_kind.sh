#!/bin/bash

# Install docker and go
#echo "================================================"
#echo "Installing Go and Docker..."
#echo "================================================"
#sudo apt install golang-go
#curl -fsSL https://get.docker.com -o get-docker.sh
#sudo sh ./get-docker.sh

# Add user to docker group
#echo ""
#echo "================================================"
#echo "Adding user to docker group..."
#echo "================================================"
#sudo groupadd docker
#sudo usermod -aG docker $USER
#newgrp docker

# Install kind (AMD64 / x86_64)
#echo ""
#echo "================================================"
#echo "Installing kind..."
#echo "================================================"
#[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
#chmod +x ./kind
#sudo mv ./kind /usr/local/bin/kind
#echo "✓ kind installed successfully"

# Install kubectl
#echo ""
#echo "================================================"
#echo "Installing kubectl..."
#echo "================================================"
#curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
#sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
#echo "✓ kubectl installed successfully"

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
