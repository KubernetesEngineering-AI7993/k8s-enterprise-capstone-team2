# Lab 02 — ConfigMaps & Secrets

## Objective
Externalize application configuration using ConfigMaps and Secrets, then inject them into Pods using both environment variables and volume mounts.

## Task 1 — Create a ConfigMap
Created a ConfigMap called `app-config` with three key-value pairs representing application settings: `APP_ENV=production`, `APP_LOG_LEVEL=info`, and `APP_PORT=8080`. ConfigMaps store non-sensitive configuration data that would otherwise be hardcoded into the container image. This lets you use the same image across dev, staging, and production — only the ConfigMap changes.

Verified with `kubectl describe configmap app-config`, which displayed all three keys and their values in plain text.

## Task 2 — Create a Secret
Created a Secret called `app-secret` with two key-value pairs: `DB_PASSWORD` and `API_KEY`. Secret values are base64-encoded in the YAML (e.g., `cGFzc3dvcmQxMjM=` decodes to `password123`). Unlike ConfigMaps, `kubectl describe secret` hides the actual values and only shows byte counts — Kubernetes intentionally protects Secrets from casual viewing.

Key difference from ConfigMaps: Secrets are meant for sensitive data (passwords, tokens, API keys). They are base64-encoded (not encrypted by default), but Kubernetes treats them with more care — they aren't printed in logs or describe output.

## Task 3 — Inject into Pods

### Method 1: Environment Variables (deploy-env.yaml)
Used `envFrom` with `configMapRef` and `secretRef` to inject all keys from both the ConfigMap and Secret as environment variables in the container. Verified with `kubectl exec deploy/app-env-demo -- env`, which showed all five variables (`APP_ENV`, `APP_LOG_LEVEL`, `APP_PORT`, `DB_PASSWORD`, `API_KEY`) available inside the container.

This method is best when your application reads config from environment variables (common in Node.js, Python, Go applications that follow the 12-factor app pattern).

### Method 2: Volume Mounts (deploy_vol.yaml)
Mounted the ConfigMap at `/etc/config` and the Secret at `/etc/secret` as volumes. Each key becomes a file inside the mount path — for example, `/etc/config/APP_ENV` is a file containing `production`, and `/etc/secret/DB_PASSWORD` is a file containing `password123`.

Verified with `kubectl exec deploy/app-vol-demo -- ls /etc/config` (showed APP_ENV, APP_LOG_LEVEL, APP_PORT) and `kubectl exec deploy/app-vol-demo -- cat /etc/config/APP_ENV` (printed `production`).

This method is best when your application reads config from files (like nginx config files, Java properties files, or SSL certificates).

## Key Concepts
- **ConfigMaps** are for non-sensitive settings. Stored in plain text. Visible in describe output.
- **Secrets** are for sensitive data. Base64-encoded. Hidden in describe output.
- **envFrom** injects all keys as environment variables — simple but the container must restart to pick up changes.
- **Volume mounts** inject keys as files — allows live updates without restarting (Kubernetes refreshes mounted ConfigMaps periodically).
- Values in YAML `data` for Secrets must be base64-encoded. Use `echo -n "myvalue" | base64` to encode.

## Troubleshooting Notes
- Continued to experience etcd timeouts due to 8GB system RAM constraints. Managed by keeping deployments to 1 replica and deleting unused Deployments before creating new ones to minimize memory pressure.

## Deliverables
- `configmap.yaml` — ConfigMap with app settings
- `secret.yaml` — Secret with sensitive credentials
- `deploy-env.yaml` — Deployment injecting ConfigMap and Secret via environment variables
- `deploy_vol.yaml` — Deployment injecting ConfigMap and Secret via volume mounts
- `lab02.sh` — Commands used throughout the lab
- `lab02.txt` — Output evidence
