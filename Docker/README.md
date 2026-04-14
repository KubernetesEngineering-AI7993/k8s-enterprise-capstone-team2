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

```powershell
docker build -t intake-service:v6 ./intake-service
docker build -t detection-service:v1 ./detection-service
docker build -t dashboard:v4 ./dashboard
```

## Environment Variables

### detection-service
| Variable | Default | Description |
|---|---|---|
| INTAKE_URL | http://intake-service:5000 | URL of the intake service |
| MODEL_PATH | best.pt | Path to YOLO weights inside container |
| CONFIDENCE_THRESHOLD | 0.25 | Minimum confidence for detections |

### dashboard
Hardcoded to `http://intake-service:5000` and `http://detection-service:5001` in app.py.
If using different internal hostnames, let Drew know and he'll refactor to env vars.

### intake-service
No configuration needed.

## Inter-Service Communication

```
dashboard:3000 ----> intake-service:5000/stream    (proxies MJPEG to browser)
dashboard:3000 ----> detection-service:5001/detect  (POST, gets JSON detections)
detection-service:5001 ----> intake-service:5000/frame  (GET, fetches single JPEG)
```

## Resource Requirements
- intake-service: needs ~2Gi memory at startup (pre-encodes 361 images, takes ~30s)
- detection-service: needs ~1Gi memory (PyTorch + YOLO model on CPU)
- dashboard: lightweight, 256Mi is fine

## Notes
- All images use python:3.11-slim base
- detection-service uses CPU-only PyTorch (no CUDA needed)
- 3 detection classes: stacked, scattered, aligned
- Liveness/readiness probes should use /health on each service's port, with initialDelaySeconds of at least 30s for intake and detection (they need time to load)
