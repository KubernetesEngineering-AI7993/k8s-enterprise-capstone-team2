#!/bin/bash
echo "=== Deploy Rolling Updates Probe ==="
sudo kubectl apply -f probes-and-rolling.yaml
echo "== Observe Rolling Updates ==="
sudo kubectl rollout status deployment/app-probes
sudo kubectl get pods
sudo kubectl logs -f app-probes-6dfbf97b7-sczlc
sudo kubectl get pods -l app=app-probes -w
echo "== Trigger Failed Deployoment ==="
sudo kubectl apply -f fail-rollout.yaml
echo "== Observe Failed Deployment ==="
sudo kubectl get pods
sudo kubectl describe pod app-probes-76766445d6-k6g8n
echo "== Roll back deployment =="
echo "== Get deployment version history and numbers =="
sudo kubectl rollout history deployment/app-probes
echo "== Fall deployment back to appropriate revision number =="
sudo kubectl rollout undo deployment/app-probes --to-revision=1
echo "== Verify rollback"
sudo kubectl rollout status deployment/app-probes
sudo kubectl get pods
sudo kubectl logs -f app-probes-6dfbf97b7-pscgl