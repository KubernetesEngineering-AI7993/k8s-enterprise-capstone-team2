#!/bin/bash
echo "=== Deploy Readiness Probe ==="
sudo kubectl apply -f add_liveness.yaml
echo "== Observe Readiness Probe ==="
sudo kubectl get pods
sudo kubectl describe pod app-demo-6cd6856876-6xx98
echo "== Deploy Failed Readiness Probe =="
sudo kubectl apply -f add_liveness_with_failure.yaml
echo "== Observe Failed Readiness Probe =="
sudo kubectl get pods -w
echo "=== Fix Readiness Probe ==="
sudo kubectl apply -f add_liveness_fixed.yaml
echo "== Observe Fixed Readiness Probe =="
sudo kubectl get pods -w