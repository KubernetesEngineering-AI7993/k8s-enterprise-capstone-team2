sudo kubectl apply -f workload-without-resource-limits.yaml
sudo kubectl top pod
sudo kubectl apply -f workload-with-resource-limits.yaml
sudo kubectl top pod
sudo kubectl describe pods resource-demo
sudo kubectl delete -f workload-with-resource-limits.yaml
sudo kubectl apply -f workload-forceOOMkill.yaml
sudo kubectl top pod
sudo kubectl describe pods resource-demo | grep -i oom

