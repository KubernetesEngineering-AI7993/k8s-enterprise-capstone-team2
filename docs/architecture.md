# Warehouse CV Environment Architecture

This document describes what is currently implemented in the repository, excluding lab material.

## System Overview

The platform runs a warehouse computer-vision pipeline in Kubernetes using three Flask services plus one scheduled training job:

- `footage-intake`: serves camera data from local image files (`/stream`, `/frame`, `/health`)
- `cv-inference`: fetches frames and runs YOLO detection (`POST /detect`, `/health`)
- `results-dashboard`: web UI and API proxy (`/`, `/proxy/stream`, `/api/health`, `/api/detect`, `/health`)
- `model-finetune`: nightly CronJob placeholder for GPU-backed training/fine-tuning

## Runtime Flow

1. Browser opens `results-dashboard`.
2. Dashboard proxies video from `footage-intake` (`/proxy/stream` -> `/stream`).
3. Dashboard polls detections (`/api/detect`), which calls `cv-inference` (`POST /detect`).
4. Inference pulls one frame from intake (`/frame`), runs YOLO, and returns JSON detections.
5. If the dashboard cannot reach inference, the current dashboard code returns randomized fallback detections so the UI can keep rendering demo data.

## Namespaces

- Application namespace: `warehouse-cv`
- Monitoring namespace: `monitoring`
- Argo CD namespace: `argocd`
- Ingress controller namespace installed by the setup script: `ingress-nginx`
- Sealed Secrets controller namespace installed by the setup script: `kube-system`

## Kubernetes Layout

### Base Resources (`k8s/base`)

- Namespace: `namespace.yaml`
- Shared platform objects: `shared.yaml`
  - `warehouse-cv-config` ConfigMap with placeholder external service URIs
  - `model-artifacts-pvc` PVC requesting `20Gi`
  - service accounts (`trainer-sa`, `intake-sa`, `inference-sa`, `dashboard-sa`)
  - dashboard read-only Role + RoleBinding
- Workloads:
  - `footage-intake.yaml` (Deployment, Service, HPA)
  - `cv-inference.yaml` (Deployment, Service)
  - `results-dashboard.yaml` (Deployment, Service, HPA)
  - `model-training.yaml` (CronJob)
- Traffic entry: `ingress.yaml`
- Secret source: `sealed-secret.yaml` (SealedSecret for `warehouse-cv-secret`)

### Workload Ports and Services

| Workload | Image | Container port | Kubernetes Service |
|---|---|---:|---|
| `footage-intake` | `intake-service:v6` | `5000` | `intake-svc:8081` |
| `cv-inference` | `detection-service:v1` | `5001` | `inference-svc:8082` |
| `results-dashboard` | `dashboard:v4` | `3000` | `dashboard-svc:8080` |

The application ingress exposes:

- `intake.warehouse-cv.internal` -> `intake-svc:8081`
- `inference.warehouse-cv.internal` -> `inference-svc:8082`
- `dashboard.warehouse-cv.internal` -> `dashboard-svc:8080`

### Scaling

Base Deployments request two replicas for each live service. The dev overlay patches all three Deployments to `replicas: 1`, but the effective runtime floor for `footage-intake` and `results-dashboard` remains two pods when the HPA controller is active because their HPAs set `minReplicas: 2`. `cv-inference` has no HPA, so the dev patch can leave it at one replica.

### Dev Overlay (`k8s/overlays/dev`)

- Includes base resources.
- Adds ingress-only NetworkPolicies:
  - default deny ingress for pods in `warehouse-cv`
  - allow ingress-nginx and allowed app-to-app ingress paths
- Adds Pod Security Admission labels (`restricted`) to the `warehouse-cv` namespace.
- Patches Deployment replica counts for dev, subject to the HPA behavior described above.

### Add-ons Overlay (`k8s/overlays/addons-dev`)

- Creates the `monitoring` namespace.
- Applies `k8s/system-ingress` for Argo CD, Prometheus, and Grafana hosts.
- Applies monitoring objects:
  - `monitoring/prometheus/servicemonitor.yaml`
  - `monitoring/grafana/warehouse-cv-overview-dashboard-configmap.yaml`

Current monitoring limitation: the ServiceMonitor scrapes `/metrics` on the application services, but the Flask apps do not currently implement `/metrics`. The Grafana dashboard ConfigMap is explicitly a placeholder and references metrics that are not produced by the current services.

## Training Job

`model-finetune` runs on the schedule `0 2 * * *`, uses `trainer-sa`, mounts `model-artifacts-pvc` at `/models`, and consumes both `warehouse-cv-config` and `warehouse-cv-secret`.

The CronJob is GPU-constrained:

- `nodeSelector: node-type: gpu`
- toleration for `gpu=true:NoSchedule`
- `nvidia.com/gpu: 1` request and limit

A default kind cluster from this repo does not create GPU-labelled nodes, so the CronJob is present but training pods will not schedule there without additional GPU node configuration.

## GitOps and Delivery

- Argo CD project: `gitops/argocd/warehouse-cv-project.yaml`
- Argo CD apps:
  - `warehouse-cv-dev` -> `k8s/overlays/dev`
  - `warehouse-cv-addons-dev` -> `k8s/overlays/addons-dev`
- Both apps use automated sync with prune, self-heal, retry, and foreground pruning options.
- CI workflow (`.github/workflows/capstone-platform-ci.yaml`) validates YAML with `yamllint`, renders the base/dev/addons Kustomize overlays, and runs kubeconform on rendered output.

## Images and Local Build Inputs

- `intake-service:v6` from `Docker/intake-service`
- `detection-service:v1` from `Docker/detection-service`
- `dashboard:v4` from `Docker/dashboard`
- `Docker/build-images.sh` builds these tags and can load them into a kind cluster.

The intake image requires image files under `Docker/intake-service/images/`; those images are intentionally not stored in the repo. `detection-service/best.pt` is stored in the repo and is copied into the detection image.