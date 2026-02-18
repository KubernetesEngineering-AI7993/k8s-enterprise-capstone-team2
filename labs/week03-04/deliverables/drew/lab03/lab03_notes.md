# Lab 03 – Horizontal Pod Autoscaler (HPA) 

## Goal
Auto-scale a Deployment based on CPU usage using an HPA.

## What I did
1) Verified metrics work using `kubectl top`.
2) Deployed a CPU-using demo app (php-apache style workload) with a CPU request.
3) Applied an HPA that targets CPU utilization.
4) Generated load by repeatedly calling the service.
5) Observed the Deployment scale up, then scale back down after load stopped.

## What it means
- The HPA watches CPU metrics for the pods in a Deployment.
- If average CPU is above the target, HPA increases replicas.
- If it’s below the target, it reduces replicas.
- HPA changes the Deployment’s desired replica count → Kubernetes creates/deletes pods to match.

## What I looked for as proof
- `kubectl get hpa` shows current CPU %, target, and replicas.
- `kubectl get deploy` shows replicas increasing/decreasing.
- `kubectl get pods` shows more or fewer pods with the app label.

## Key takeaway
HPA does not “add CPU.” It adds or removes replicas based on observed CPU usage.
