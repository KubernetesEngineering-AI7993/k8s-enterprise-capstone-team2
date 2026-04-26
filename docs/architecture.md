# Warehouse CV Environment Architecture

This document describes what is currently implemented in the repository.

## System Overview

The platform runs a warehouse computer-vision pipeline in Kubernetes using three live Flask services plus one scheduled training job:

- `footage-intake`: serves camera data from local images (`/stream`, `/frame`, `/health`)
- `cv-inference`: fetches frames and runs YOLO detection (`/detect`, `/health`)
- `results-dashboard`: web UI and API proxy (`/`, `/proxy/stream`, `/api/health`, `/api/detect`, `/health`)
- `model-finetune`: nightly CronJob placeholder for training/fine-tuning

## Runtime Flow

1. Browser opens `results-dashboard`.
2. Dashboard proxies video from `footage-intake` (`/proxy/stream` -> `/stream`).
3. Dashboard requests detections from `cv-inference` (`/api/detect` -> `/detect`).
4. Inference pulls a frame from intake (`/frame`), runs YOLO, returns JSON detections.

## Kubernetes Layout

### Namespace

- Application namespace: `warehouse-cv`
- Monitoring namespace: `monitoring`
- Argo CD namespace: `argocd`

### Base Resources (`k8s/base`)

- Namespace: `namespace.yaml`
- Shared platform objects: `shared.yaml`
  - `warehouse-cv-config` ConfigMap
  - `model-artifacts-pvc` PVC
  - service accounts (`trainer-sa`, `intake-sa`, `inference-sa`, `dashboard-sa`)
  - dashboard read-only Role + RoleBinding
- Workloads:
  - `footage-intake.yaml` (Deployment, Service, HPA)
  - `cv-inference.yaml` (Deployment, Service)
  - `results-dashboard.yaml` (Deployment, Service, HPA)
  - `model-training.yaml` (CronJob)
- Traffic entry: `ingress.yaml`
- Secret source: `sealed-secret.yaml` (SealedSecret)

### Dev Overlay (`k8s/overlays/dev`)

- Includes base resources.
- Adds ingress-focused NetworkPolicies.
- Adds namespace pod-security labels (`restricted`).
- Patches all Deployments to `replicas: 1` for dev.

### Add-ons Overlay (`k8s/overlays/addons-dev`)

- Creates `monitoring` namespace.
- Applies `k8s/system-ingress.yaml` for Argo CD / Prometheus / Grafana hosts.
- Applies monitoring objects:
  - `monitoring/prometheus/servicemonitor.yaml`
  - `monitoring/grafana/warehouse-cv-overview-dashboard-configmap.yaml`

## GitOps and Delivery

- Argo CD project: `gitops/argocd/warehouse-cv-project.yaml`
- Argo CD apps:
  - `warehouse-cv-dev` -> `k8s/overlays/dev`
  - `warehouse-cv-addons-dev` -> `k8s/overlays/addons-dev`
- Both apps use automated sync with prune and self-heal.
- CI workflow (`.github/workflows/capstone-platform-ci.yaml`) validates YAML, renders kustomizations, and runs kubeconform on rendered output.

## Images and Service Code

- `intake-service:v6` from `Docker/intake-service`
- `detection-service:v1` from `Docker/detection-service`
- `dashboard:v4` from `Docker/dashboard`
- `Docker/build-images.sh` builds these tags and can load them into kind.