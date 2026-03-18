# Lab 01 - Helm Charts
helm create sample-app
helm template my-release ./sample-app
helm template my-release ./sample-app --set replicaCount=3 --set service.type=NodePort --set image.tag=1.27
helm install sample-app ./sample-app
helm list
kubectl get pods
helm upgrade sample-app ./sample-app --set replicaCount=2
helm list
helm rollback sample-app 1
helm list
helm history sample-app