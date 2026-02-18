#!/usr/bin/env bash
set -e

# Lab 04 – Troubleshooting Failing Workloads
# Debug loop used in every scenario:
#   kubectl get -> kubectl describe -> kubectl logs -> kubectl get events
#
# NOTES:
# I used the same YAML file for the "broken" and "fixed" runs.
# The YAML was updated between runs (first applied in its broken form,
# then edited/saved, then applied again as the fixed form).



NS="${NS:-dev}"

# File names (same file used for broken and fixed runs)
CRASH_BROKEN="${CRASH_BROKEN:-./lab04/crashloop.yaml}"
CRASH_FIXED="${CRASH_FIXED:-./lab04/crashloop.yaml}"

IMAGE_BROKEN="${IMAGE_BROKEN:-./lab04/imagepull.yaml}"
IMAGE_FIXED="${IMAGE_FIXED:-./lab04/imagepull.yaml}"

PENDING_BROKEN="${PENDING_BROKEN:-./lab04/pending.yaml}"
PENDING_FIXED="${PENDING_FIXED:-./lab04/pending.yaml}"

SVC_BROKEN="${SVC_BROKEN:-./lab04/svc-mismatch.yaml}"
SVC_FIXED="${SVC_FIXED:-./lab04/svc-mismatch.yaml}"

# Resource names
CRASH_DEPLOYMENT="${CRASH_DEPLOYMENT:-crashloop-demo}"
CRASH_LABEL="${CRASH_LABEL:-app=crashloop-demo}"

IMAGE_POD_NAME="${IMAGE_POD_NAME:-imagepull-demo}"
PENDING_POD_NAME="${PENDING_POD_NAME:-pending-demo}"

SVC_DEPLOYMENT="${SVC_DEPLOYMENT:-svc-demo}"
SVC_NAME="${SVC_NAME:-svc-demo}"

echo "Scenario 1: CrashLoopBackOff "
echo "Deploying failing workload"
kubectl apply -n "$NS" -f "$CRASH_BROKEN"
sleep 10
kubectl get pods -n "$NS" -o wide
kubectl describe pod -n "$NS" -l "$CRASH_LABEL" || true
kubectl logs -n "$NS" -l "$CRASH_LABEL" --previous --tail=50 || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete -n "$NS" deployment "$CRASH_DEPLOYMENT" --ignore-not-found
kubectl wait -n "$NS" --for=delete deployment/"$CRASH_DEPLOYMENT" --timeout=60s 2>/dev/null || true


echo "Deploying fixed workload (crashloop.yaml updated)"
kubectl delete -n "$NS" deployment "$CRASH_DEPLOYMENT" --ignore-not-found
kubectl wait -n "$NS" --for=delete deployment/"$CRASH_DEPLOYMENT" --timeout=60s 2>/dev/null || true
kubectl apply -n "$NS" -f "$CRASH_FIXED"
kubectl wait -n "$NS" --for=condition=available --timeout=60s deployment/"$CRASH_DEPLOYMENT"
kubectl get pods -n "$NS" -o wide
kubectl describe pod -n "$NS" -l "$CRASH_LABEL" || true
kubectl logs -n "$NS" -l "$CRASH_LABEL" --tail=50 || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete -n "$NS" deployment "$CRASH_DEPLOYMENT" --ignore-not-found
kubectl wait -n "$NS" --for=delete deployment/"$CRASH_DEPLOYMENT" --timeout=60s 2>/dev/null || true



echo "Scenario 2: ImagePullBackOff"
echo "Deploying failing workload (imagepull.yaml)"
kubectl apply -n "$NS" -f "$IMAGE_BROKEN"
sleep 15
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$IMAGE_POD_NAME" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete pod "$IMAGE_POD_NAME" -n "$NS" --ignore-not-found
kubectl wait -n "$NS" --for=delete pod/"$IMAGE_POD_NAME" --timeout=60s 2>/dev/null || true


echo "Deploying fixed workload (imagepull.yaml updated)"
kubectl delete pod "$IMAGE_POD_NAME" -n "$NS" --ignore-not-found
kubectl wait -n "$NS" --for=delete pod/"$IMAGE_POD_NAME" --timeout=60s 2>/dev/null || true
kubectl apply -n "$NS" -f "$IMAGE_FIXED"
kubectl wait -n "$NS" --for=condition=Ready --timeout=60s pod/"$IMAGE_POD_NAME" || true
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$IMAGE_POD_NAME" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete pod "$IMAGE_POD_NAME" -n "$NS" --ignore-not-found
kubectl wait -n "$NS" --for=delete pod/"$IMAGE_POD_NAME" --timeout=60s 2>/dev/null || true



echo "Scenario 3: Pending Pods"
echo "Deploying failing workload"
kubectl apply -n "$NS" -f "$PENDING_BROKEN"
sleep 8
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$PENDING_POD_NAME" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete pod "$PENDING_POD_NAME" -n "$NS" --ignore-not-found
kubectl wait -n "$NS" --for=delete pod/"$PENDING_POD_NAME" --timeout=60s 2>/dev/null || true


echo "Deploying fixed workload (pending.yaml updated)"
kubectl delete pod "$PENDING_POD_NAME" -n "$NS" --ignore-not-found
kubectl wait -n "$NS" --for=delete pod/"$PENDING_POD_NAME" --timeout=60s 2>/dev/null || true
kubectl apply -n "$NS" -f "$PENDING_FIXED"
kubectl wait -n "$NS" --for=condition=Ready --timeout=60s pod/"$PENDING_POD_NAME" || true
kubectl get pods -n "$NS" -o wide
kubectl describe pod "$PENDING_POD_NAME" -n "$NS" || true
kubectl get events -n "$NS" --sort-by=.lastTimestamp || true
kubectl delete pod "$PENDING_POD_NAME" -n "$NS" --ignore-not-found
kubectl wait -n "$NS" --for=delete pod/"$PENDING_POD_NAME" --timeout=60s 2>/dev/null || true



echo "Scenario 4: Service selector mismatch"
echo "Deploying service with selector mismatch"
kubectl apply -n "$NS" -f "$SVC_BROKEN"
kubectl wait -n "$NS" --for=condition=available --timeout=60s deployment/"$SVC_DEPLOYMENT" 2>/dev/null || true
sleep 3
kubectl describe service "$SVC_NAME" -n "$NS" || true
kubectl get endpoints "$SVC_NAME" -n "$NS" || true
kubectl get endpointslice -n "$NS" -l kubernetes.io/service-name="$SVC_NAME" || true
kubectl delete -n "$NS" -f "$SVC_BROKEN" --ignore-not-found
kubectl wait -n "$NS" --for=delete deployment/"$SVC_DEPLOYMENT" --timeout=60s 2>/dev/null || true


echo "Deploying fixed service (svc-mismatch.yaml updated)"
kubectl apply -n "$NS" -f "$SVC_FIXED"
kubectl wait -n "$NS" --for=condition=available --timeout=60s deployment/"$SVC_DEPLOYMENT" 2>/dev/null || true
sleep 3
kubectl describe service "$SVC_NAME" -n "$NS" || true
kubectl get endpoints "$SVC_NAME" -n "$NS" || true
kubectl get endpointslice -n "$NS" -l kubernetes.io/service-name="$SVC_NAME" || true
kubectl delete -n "$NS" -f "$SVC_FIXED" --ignore-not-found
kubectl wait -n "$NS" --for=delete deployment/"$SVC_DEPLOYMENT" --timeout=60s 2>/dev/null || true
