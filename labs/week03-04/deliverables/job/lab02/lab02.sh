sudo kubectl get nodes
sudo kubectl taint nodes jeking-vm dedicated=ops:NoSchedule
sudo kubectl apply -f taints-no-tolerance.yaml
sudo kubectl get pods
sudo kubectl describe pods toleration-demo
sudo kubectl delete -f taints-no-tolerance.yaml
sudo kubectl get pods
sudo kubectl apply -f taints-tolerance.yaml
sudo kubectl get pods
sudo kubectl describe pods toleration-demo
sudo kubectl delete -f taints-tolerance.yaml
sudo kubectl label nodes jeking-vm dedicated=ai7993
sudo kubectl apply -f taints-nodeselector.yaml
sudo kubectl describe pods toleration-demo
sudo kubectl get pods