sudo kubectl get deployment metrics-server -n kube-system
sudo kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes"
sudo kubectl apply -f sample-deployment.yaml
sudo kubectl apply -f sample-service.yaml
sudo kubectl apply -f hpa.yaml
sudo kubectl get hpa
sudo kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://sample-app; done"
sudo kubectl get hpa sample-hpa --watch
sudo kubectl get pods -l app=sample-app --watch