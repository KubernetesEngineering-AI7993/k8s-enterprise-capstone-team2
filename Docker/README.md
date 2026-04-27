# Docker Images - MLOps Warehouse Pipeline

## Containers (3 total)

| Container | Port | Description |
|---|---|---|
| intake-service | 5000 | Flask app serving 361 warehouse images as MJPEG stream (simulated camera feed) |
| detection-service | 5001 | Flask app running YOLOv8n-seg inference on frames fetched from intake |
| dashboard | 3000 | Flask web UI showing live stream, detection results, service health, class summary |

## Before You Build

### intake-service/images/ (361 JPEGs, ~250MB)
These are NOT in the repo (too large for git). Download the "Warehouse Delivery Box Detection" dataset from Kaggle, then copy the training images:
```powershell
Copy-Item "path\to\Box Dataset\train\images\*" -Destination "Docker\intake-service\images\"
```
The Dockerfile bakes these into the image at build time. Without them the build will fail.

### detection-service/best.pt
Trained YOLOv8n-seg model weights (~6MB). This IS included in the repo, no extra steps needed.

## Build Commands

From the repo root (or `Docker/`), run:

```bash
./Docker/build-images.sh
```

After the kind cluster exists (e.g. from `scripts/cluster-setup.sh`), load images into it:

```bash
./Docker/build-images.sh --load-kind
```

Equivalent manual `docker build` lines:

```powershell
docker build -t intake-service:v6 ./intake-service
docker build -t detection-service:v1 ./detection-service
docker build -t dashboard:v4 ./dashboard
```

## Environment Variables

### detection-service
| Variable | Default | Description |
|---|---|---|
| INTAKE_URL | http://intake-svc:8081 | URL of the intake **Kubernetes Service** (matches `k8s/base/footage-intake.yaml`) |
| MODEL_PATH | best.pt | Path to YOLO weights inside container |
| CONFIDENCE_THRESHOLD | 0.25 | Minimum confidence for detections |

### dashboard
| Variable | Default | Description |
|---|---|---|
| INTAKE_URL | http://intake-svc:8081 | Intake service URL |
| DETECTION_URL | http://inference-svc:8082 | Detection service URL |

Override via env when not using the repo’s Kubernetes Service names/ports.

### intake-service
No configuration needed.

## Inter-Service Communication

Container ports remain 5000 / 5001 / 3000. In Kubernetes, Services expose **8081 / 8082 / 8080** and forward to those ports (`intake-svc`, `inference-svc`, `dashboard-svc` in `k8s/base/footage-intake.yaml`, `k8s/base/cv-inference.yaml`, and `k8s/base/results-dashboard.yaml`).

```
dashboard (pod :3000) ----> http://intake-svc:8081/stream     (proxies MJPEG to browser)
dashboard (pod :3000) ----> http://inference-svc:8082/detect  (POST, JSON detections)
detection (pod :5001) ----> http://intake-svc:8081/frame      (GET, single JPEG)
```

## Resource Requirements
- intake-service: Kubernetes requests 2Gi and limits 3Gi; current code pre-encodes resized JPEG stream frames instead of raw pixels to reduce memory pressure
- detection-service: needs ~1Gi memory (PyTorch + YOLO model on CPU)
- dashboard: lightweight, 256Mi is fine

## Notes
- All images use python:3.11-slim base
- detection-service uses CPU-only PyTorch (no CUDA needed)
- 3 detection classes: stacked, scattered, aligned
- Liveness/readiness probes should use /health on each service's port, with initialDelaySeconds of at least 30s for intake and detection (they need time to load)
