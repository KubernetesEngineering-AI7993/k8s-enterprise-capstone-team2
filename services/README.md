# Services Contract (Placeholder Phase)

This directory is intentionally lightweight because application/container implementation is owned by teammate tracks.

## Planned Services

- `training`: model training and fine-tune job image
- `intake`: camera ingestion and buffering service
- `inference`: object detection + tracking service (GPU)
- `dashboard`: API + frontend visualization service

## Expected Runtime Contracts

- All services should expose Prometheus metrics at `/metrics`.
- Intake and inference should emit structured logs with camera ID, frame timestamp, and processing latency.
- Inference image should support model artifact pull from registry/object storage path provided via environment variables.
- Dashboard should read from the shared results store and avoid direct DB credentials in source code.

## Integration Target

Workloads in `k8s/base/platform.yaml` currently use bare Ubuntu placeholders and are intended to be swapped one-by-one with real images as they become available.
