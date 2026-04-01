# Lab 04 – Deployment Validation: Notes & Validation Logic

---

## What is Deployment Validation?

Deployment validation is the practice of checking Kubernetes manifests against
a set of standards before they are applied to a cluster. It is a form of
shift-left security and reliability enforcement — catching problems at the
manifest level, in CI, rather than after a broken or insecure workload reaches
production.

The validator in this lab (`validate.sh`) works entirely on raw YAML. It uses
Python's `PyYAML` to parse manifests and checks each Deployment's containers
against four rules. Because it exits with code `1` on any failure, it can be
used as a blocking gate in any CI pipeline.

---

## The Four Checks

### Check 1 – Resource Limits (cpu + memory)

```yaml
resources:
  limits:
    cpu: 200m
    memory: 256Mi
```

**Why it matters:** Without resource limits, a single runaway pod can consume
all CPU and memory on a node, evicting every other workload on it. Kubernetes
will not enforce any ceiling on the container's consumption.

**What the validator checks:** Both `resources.limits.cpu` and
`resources.limits.memory` must be set on every container. A deployment with
only one of the two still fails — an uncapped memory limit is as dangerous
as no limit at all.

**Common mistake:** Setting `requests` without `limits`. Requests affect
scheduling (the scheduler finds a node with enough headroom) but do not cap
runtime consumption. Only `limits` prevents a container from exceeding its
allocation.

---

### Check 2 – No `:latest` Image Tag

```yaml
# Bad
image: adguard/adguardhome:latest

# Good
image: adguard/adguardhome:v0.107.53
```

**Why it matters:** The `:latest` tag is mutable — the image it points to can
change between pod restarts without any change to the manifest. This causes:
- Non-reproducible deployments (two pods in the same ReplicaSet may run
  different image versions)
- Unpredictable rollouts when `imagePullPolicy: Always` is set
- Inability to pin a known-good version after a bad upstream release

**What the validator checks:** The image field must contain a `:` tag separator
and the tag must not be `latest`. Images with no tag at all (implicit `latest`)
also fail. Digest pinning (`image@sha256:...`) is accepted as an even stronger
form of pinning.

---

### Check 3 – Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 3000
  initialDelaySeconds: 30
  periodSeconds: 15
```

**Why it matters:** A liveness probe tells kubelet whether the container is
still alive and functioning. Without one, if the application deadlocks or
enters a broken state (responding to nothing but not crashed), the container
will run indefinitely with no automatic recovery. Kubelet only restarts
containers that exit — a stuck process never exits.

**What the validator checks:** Any liveness probe type is accepted
(`httpGet`, `tcpSocket`, or `exec`). The validator only checks for presence,
not probe parameters — teams set their own timeouts and thresholds.

---

### Check 4 – Readiness Probe

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 3000
  initialDelaySeconds: 15
  periodSeconds: 10
```

**Why it matters:** A readiness probe tells Kubernetes when a pod is ready to
receive traffic. Without one, the Service will route requests to a pod the
moment it starts — before the application has finished initializing. This
causes failed requests during deployments and restarts, and is a common source
of transient errors in rolling updates.

**Liveness vs readiness — the key difference:**
- Liveness failure → pod is **restarted**
- Readiness failure → pod is **removed from Service endpoints** (not restarted)

Both are needed. A pod can be alive (not deadlocked) but not yet ready (still
loading config). Liveness alone does not protect users from requests hitting
an initializing container.

---

## Comparison: Script vs OPA/Gatekeeper

| Factor | validate.sh (this lab) | OPA/Gatekeeper |
|---|---|---|
| Where it runs | CI pipeline, local | In-cluster admission webhook |
| Blocks deployment | Yes (via exit code in CI) | Yes (via HTTP 403 from API server) |
| Cluster required | No | Yes |
| Policy language | Bash + Python | Rego |
| Catches drift | No | Yes — blocks even `kubectl apply` directly |
| Setup complexity | None | Moderate (CRDs, webhook config) |
| Best for | CI shift-left validation | Runtime enforcement |

The two approaches are complementary. Script-based validation catches issues
early in CI before they reach the cluster. Gatekeeper provides a second line
of defence at the API server level, blocking even out-of-band `kubectl apply`
commands that bypass CI.

---

## Using the Validator in CI (Gitea Actions)

```yaml
- name: Validate manifests
  run: |
    pip3 install pyyaml --break-system-packages
    bash labs/week09-10/Deliverables/kunal/lab04/validate.sh \
      labs/week09-10/Deliverables/kunal/lab04/
```

Because `validate.sh` exits with `1` on failure, Gitea Actions will mark the
step as failed and stop the pipeline — the same pattern used with
`--exit-code 1` in the Trivy lab. The two together form a basic shift-left
security and reliability gate:

1. `trivy image` — blocks images with known CVEs
2. `validate.sh` — blocks manifests that violate operational standards
