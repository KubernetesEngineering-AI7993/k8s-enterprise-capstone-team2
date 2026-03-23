# Lab 02 - Secrets Management

## Objective
Create Kubernetes Secrets using both imperative and declarative methods, inject them into Pods via environment variables and volume mounts, and understand best practices for secrets handling.

## What We Did

### Created a Secret Imperatively (the secure way)
Ran kubectl create secret generic app-credentials --from-literal=DB_PASSWORD=supersecret123 --from-literal=API_KEY=sk-live-abc123. This creates the Secret directly in the cluster with no file on disk and nothing to commit to git. The password only exists inside Kubernetes. This is the production-safe approach.

### Created a Secret via YAML (for learning)
Created secret.yaml with base64-encoded values (DB_USER=admin, DB_NAME=production_db). This demonstrates the declarative approach but should NOT be committed to git in a real environment because base64 is encoding, not encryption. Anyone can decode it.

### Injected Secrets into a Pod Two Ways
Created a Pod (secret-pod.yaml) that demonstrates both injection methods simultaneously:
- Environment variables: envFrom with secretRef pulled app-credentials into env vars. kubectl exec -- env showed DB_PASSWORD and API_KEY as plain text variables inside the container.
- Volume mounts: Mounted app-secret-yaml at /etc/secrets/. Each key became a file (DB_USER, DB_NAME) with the decoded value as contents.

### Examined Secret Visibility
- kubectl describe secret: hides values, shows only byte count (e.g., API_KEY: 14 bytes)
- kubectl get secret -o yaml: reveals base64-encoded values (anyone with access can decode)
- Inside the container: env vars and mounted files are plain text

## Environment Variables vs Volume Mounts

Environment variables are best for simple key-value settings like passwords and connection strings. Most applications expect configuration from env vars. The downside is the Pod must restart to pick up changes.

Volume mounts are best for file-based data like TLS certificates, SSH keys, or config files. Nginx expects certificates at a file path, not as an env var. The upside is Kubernetes auto-refreshes mounted files without restarting the Pod.

## Security Best Practices

### What Kubernetes Secrets Provide
- Values hidden from kubectl describe output
- Can be scoped with RBAC (control who can read secrets)
- Keep sensitive data out of YAML files and git history
- Can be encrypted at rest in etcd if configured

### What Kubernetes Secrets Do NOT Provide
- Encryption (base64 is encoding, not encryption)
- Protection from anyone with kubectl get secret access
- Protection inside the container (env and cat expose values)
- Protection in etcd by default (stored as plain text)

### Production Solutions 
- Sealed Secrets: encrypt before committing to git, only the cluster can decrypt
- External Secrets Operator: pulls secrets from AWS Secrets Manager, HashiCorp Vault, or Azure Key Vault at runtime
- HashiCorp Vault: dedicated secrets management system, apps authenticate and request secrets directly
- RBAC restrictions: limit who can run kubectl get secrets

### The Security Progression
Hardcoded in YAML (worst) -> Kubernetes Secrets (better) -> Sealed Secrets (good) -> External Vault (best)


## Deliverables
- secret.yaml: Secret manifest (non-sensitive, for learning)
- secret-pod.yaml: Pod using both env var and volume mount injection
- lab02.txt: output evidence
- lab02_notes.md: this file
