 sudo kubectl apply -f crashloop.yaml
 sudo kubectl describe deployment crashloop-demo
 sudo kubectl get pods
 sudo kubectl describe pod crashloop-demo-6587886f59-jvdwk
 sudo kubectl get events | grep crashloop-demo-6587886f59-jvdwk
sudo kubectl apply -f crashloop.yaml
sudo kubectl describe deployment crashloop-demo
sudo kubectl get pods
sudo kubectl describe pod crashloop-demo-6587886f59-jvdwk
sudo kubectl get events | grep crashloop-demo-6587886f59-jvdwk
sudo kubectl logs crashloop-demo-6587886f59-jvdwk
sudo kubectl apply -f crashloop-fixed.yaml
sudo kubectl get pods
sudo kubectl describe pod crashloop-demo-8665695cb6-xxv49
sudo kubectl get events | grep crashloop-demo-8665695cb6-xxv49
sudo kubectl logs crashloop-demo-8665695cb6-xxv49