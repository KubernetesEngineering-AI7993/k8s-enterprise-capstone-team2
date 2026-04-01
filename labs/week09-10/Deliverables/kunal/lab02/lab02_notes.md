# Lab 02 – Secrets Management: Notes & Best Practices

---

## What is a Kubernetes Secret?

A Kubernetes Secret is an object that stores sensitive data — passwords, tokens,
TLS certificates, API keys — separately from Pod specs and application code.
Secrets are base64-encoded (not encrypted by default) and made available to Pods
either as environment variables or as mounted files.

> **Important:** Base64 is encoding, not encryption. Anyone with access to the
> Secret object can decode the value instantly. Encryption at rest requires
> additional cluster configuration (EncryptionConfiguration) or external tooling.

---

## Secret Types Used in This Lab

| Type | Manifest | Purpose |
|---|---|---|
| `Opaque` | `secret-generic.yaml` | General-purpose key/value secrets |
| `kubernetes.io/tls` | `secret-tls.yaml` | TLS certificate + private key pairs |

Other built-in types include `kubernetes.io/dockerconfigjson` (registry auth),
`kubernetes.io/ssh-auth` (SSH keys), and `kubernetes.io/service-account-token`.

---

## Creating Secrets: Two Methods

### Method A – Imperative (`kubectl create secret`)
```bash
kubectl create secret generic adguard-credentials \
  --from-literal=admin-username=admin \
  --from-literal=admin-password=changeme123 \
  -n adguard-home
```
Good for: one-off creation, testing, CI pipelines.  
Bad for: GitOps — the command is not declarative and leaves no artifact in Git.

### Method B – Declarative (YAML manifest)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: adguard-credentials
  namespace: adguard-home
type: Opaque
data:
  admin-password: Y2hhbmdlbWUxMjM=   # base64 encoded
```
Good for: GitOps workflows, consistency, auditability.  
Bad for: committing real credentials — the base64 value is trivially decoded.

---

## Injection Method 1: Environment Variables

```yaml
env:
  - name: ADGUARD_PASSWORD
    valueFrom:
      secretKeyRef:
        name: adguard-credentials
        key: admin-password
```

**How it works:** The kubelet resolves the Secret reference at Pod startup and
injects the decoded value as a process environment variable.

**Security considerations:**
- Env vars are visible in `kubectl describe pod` output
- They appear in `/proc/<pid>/environ` on the node
- Child processes inherit all env vars
- If the Secret is updated, the Pod must restart to pick up the new value
- Use only when the application requires env var configuration

---

## Injection Method 2: Mounted Volume

```yaml
volumeMounts:
  - name: adguard-secrets
    mountPath: /etc/adguard/secrets
    readOnly: true
volumes:
  - name: adguard-secrets
    secret:
      secretName: adguard-credentials
      defaultMode: 0400
```

**How it works:** The kubelet creates a tmpfs (in-memory) volume and writes each
Secret key as a file. The files are updated automatically when the Secret changes
(within ~1 minute kubelet sync period) without restarting the Pod.

**Security considerations:**
- Files are stored in memory (tmpfs), not on disk
- Tighter file permissions possible (`defaultMode: 0400` = owner read-only)
- Not visible in `kubectl describe pod` environment section
- Supports automatic rotation without Pod restart
- Preferred method for production workloads

---

## Comparison: Env Vars vs Volume Mounts

| Factor | Environment Variables | Volume Mounts |
|---|---|---|
| Visibility in `kubectl describe` | Yes — shown in env section | No |
| Auto-update on Secret change | No — requires Pod restart | Yes — within ~60s |
| File permissions control | No | Yes (`defaultMode`) |
| App compatibility | Any app | App must read from files |
| Audit surface | Higher | Lower |
| Recommended for production | No | Yes |

---

## Best Practices for Secrets Management

### 1. Never commit plaintext secrets to Git
Even in private repos — Git history is permanent. Use placeholder values in
manifests committed to Git and inject real values through a secrets manager.

### 2. Enable encryption at rest
By default, Kubernetes stores Secrets as plaintext in etcd. Enable
`EncryptionConfiguration` with AES-GCM or use a KMS provider to encrypt
Secret data at rest in etcd.

```yaml
# /etc/kubernetes/encryption-config.yaml (control plane)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources: [secrets]
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}
```

### 3. Use RBAC to restrict Secret access
Secrets are namespace-scoped. Use RBAC to ensure only the ServiceAccounts
and users that need a Secret can read it.

```bash
# Check who can read secrets in a namespace
kubectl auth can-i get secrets -n adguard-home --as=system:serviceaccount:default:default
```

### 4. Prefer volume mounts over environment variables
As shown in this lab, volume mounts are harder to accidentally leak, support
automatic rotation, and allow tighter file permissions.

### 5. Use `stringData` for readability in non-production manifests
`stringData` lets you write plaintext values in the manifest — Kubernetes
encodes them at apply time. Still not safe to commit, but easier to read
during development.

```yaml
stringData:
  admin-password: changeme123   # Kubernetes base64-encodes this automatically
```

---

## Optional: Sealed Secrets (Conceptual)

**Sealed Secrets** (by Bitnami) solves the "don't commit secrets to Git" problem
while keeping a GitOps workflow intact.

**How it works:**
1. A controller runs in the cluster and holds a private key
2. You encrypt your Secret using `kubeseal` and the controller's public key
3. The resulting `SealedSecret` YAML is safe to commit — it can only be
   decrypted by that specific cluster's controller
4. The controller decrypts it and creates the real `Secret` in the cluster

```bash
# Install kubeseal CLI, then:
kubeseal --format yaml < secret-generic.yaml > sealed-secret-generic.yaml
git add sealed-secret-generic.yaml   # Safe to commit
```

**Tradeoff:** The secret is tied to that cluster's key. If the cluster is
destroyed and the key is lost, the sealed secret cannot be recovered.

---

## Optional: External Secrets Operator (Conceptual)

**External Secrets Operator (ESO)** integrates Kubernetes with external secrets
managers — AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager, Azure Key Vault.

**How it works:**
1. ESO is installed in the cluster
2. You create an `ExternalSecret` manifest that references a path in your
   secrets manager (e.g. `aws/adguard/admin-password`)
3. ESO fetches the value from the external store and creates a standard
   Kubernetes `Secret` automatically
4. The `ExternalSecret` manifest (no actual secret values) is safe to commit to Git

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: adguard-credentials
  namespace: adguard-home
spec:
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: adguard-credentials
  data:
    - secretKey: admin-password
      remoteRef:
        key: adguard/admin-password
```

**Best fit for:** Teams already using a cloud secrets manager. Production
Kubernetes deployments where secret rotation and auditing are required.
