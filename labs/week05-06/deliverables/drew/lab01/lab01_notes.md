# Lab 01 — Deployments & Services

## Objective
Deploy a stateless application, expose it with a Service, scale replicas, and verify traffic flow across all Pods.

## Cluster Setup
- Created a fresh kind cluster: `kind create cluster --name cka-labs05-06 --image kindest/node:v1.32.2`
- Pinned to v1.32.2 because the default v1.35.0 image caused a kubelet timeout during cluster creation
- Created a `labs` namespace and set it as the default context

## Task 1 — Deploy a Stateless Application
Created a Deployment running nginx:1.27 with 2 replicas. The Deployment manages a ReplicaSet, which in turn creates and monitors the Pods. Key configuration:
- `replicas: 2` ensures two identical Pods are always running
- `selector.matchLabels: app: nginx` tells the Deployment which Pods it owns
- `template.metadata.labels: app: nginx` labels each Pod so the selector can find them
- These labels must match — a mismatch is the most common Deployment error

Applied with `kubectl apply -f deployment.yaml` and verified both Pods reached Running status.

## Task 2 — Expose with a Service
Created a ClusterIP Service to give the Pods a stable network endpoint. Key configuration:
- `selector: app: nginx` matches the Pod labels from the Deployment
- `port: 80` is what clients call; `targetPort: 80` is what the container listens on
- `type: ClusterIP` makes it internal-only (default)

Verified with `kubectl get endpoints nginx-service`, which showed both Pod IPs — confirming the selector matched and traffic would be routed correctly. Tested with `kubectl port-forward service/nginx-service 8080:80` and confirmed the nginx welcome page loaded at localhost:8080.

## Task 3 — Scale Replicas and Test Traffic Flow
Scaled the Deployment from 2 to 4 replicas using `kubectl scale deployment nginx-deployment --replicas=4`. After scaling:
- `kubectl get pods` confirmed 4 Pods running
- `kubectl get endpoints nginx-service` showed 4 Pod IPs automatically — the Service discovered the new Pods without any reconfiguration

This demonstrates Kubernetes self-healing and service discovery: the Deployment maintains the desired replica count, and the Service dynamically tracks all matching Pods.

## Troubleshooting Notes
- **etcd timeouts**: Encountered `etcdserver: request timed out` errors caused by Docker Desktop running low on resources (a full Supabase stack was running alongside the cluster). Fixed by stopping the Supabase containers to free memory. Lesson: check `docker ps` when cluster commands start timing out.
- **Cluster recreation**: After persistent etcd issues, deleted and recreated the cluster. Since all YAMLs were saved on disk, full recovery took under 2 minutes with `kubectl apply`.

## Deliverables
- `deployment.yaml` — Deployment with 2 replicas
- `deployment-scaled.yaml` — Deployment with 4 replicas
- `service.yaml` — ClusterIP Service
- `lab01.sh` — Commands used throughout the lab
- `lab01.txt` — Output evidence (deployments, pods, services, endpoints)
