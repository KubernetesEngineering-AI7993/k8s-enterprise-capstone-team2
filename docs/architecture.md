# Kubernetes Enterprise Capstone - Warehouse CV Architecture

## Goal

Run live warehouse object detection on Kubernetes with strong alignment to CKA, CKAD, and CKS practices
## Workload Topology

- **Model training/fine-tune**: `CronJob` scheduled nightly on GPU nodes; writes model artifacts to a shared PVC.
- **Footage intake**: `Deployment` for ingesting camera stream metadata and forwarding events to inference.
- **CV inference/tracking**: `Deployment` on GPU nodes for detection/tracking processing.
- **Results dashboard**: `Deployment` on standard nodes for visualization and operator workflows.
- **Ingress**: NGINX Ingress routes traffic to dashboard service.

## Scheduling and Capacity Design

- GPU workloads (`model-finetune`, `cv-inference`) use:
  - `nodeSelector: node-type=gpu`
  - `tolerations` for tainted GPU nodes
  - `nvidia.com/gpu` requests/limits
- Non-GPU workloads (`footage-intake`, `results-dashboard`) use standard node pools with smaller resource requests.
- HPA is enabled for intake and dashboard to absorb workload spikes.

## Configuration and Release Design

- Runtime configuration is centralized with:
  - `ConfigMap`: deployment mode, footage source URI, model registry URI, results store URI
  - `Secret`: object storage credentials placeholder
- Delivery models:
  - `k8s/base` + `k8s/overlays/dev` for Kustomize-based GitOps
  - `helm/warehouse-cv` as chart foundation for environment-specific values
- ArgoCD definitions live in `gitops/argocd` and point at `k8s/overlays/dev`.

## Repository Implementation Map

- `k8s/`: core platform resources, overlays, security policies
- `gitops/`: ArgoCD project/application manifests
- `helm/`: reusable chart for placeholder platform
- `ci/`: YAML + Helm + Kustomize validation pipeline
- `monitoring/`: ServiceMonitor and Grafana dashboard-as-code
- `services/`: placeholder interfaces/contracts for teammate-owned app containers
