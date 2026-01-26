# Install docker and go
sudo apt install golang-go
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh
# Add user to dockergroup
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
# Install kind (AMD64 / x86_64)
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
# Create cluster
kind create cluster --name test-k8s --config kind.yaml
# Get info
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info
kubectl config get-contexts
kubectl config current-context
