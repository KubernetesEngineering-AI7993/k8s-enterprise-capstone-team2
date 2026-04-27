# Pod Security Standards — What Changed and Why It's Safer

> Kubernetes "restricted" profile · `dev` namespace · PSA enforce mode

---

## The Three PSS Tiers

Kubernetes ships three built-in Pod Security Standard profiles, enforced by the **Pod Security Admission (PSA)** controller (stable since 1.25, replacing the deprecated PodSecurityPolicy):

| Profile | What it allows | Typical use |
|---|---|---|
| `privileged` | Everything — no restrictions | Cluster infrastructure, node agents |
| `baseline` | Blocks the most dangerous settings (hostNetwork, hostPID, privileged) | General workloads |
| `restricted` | Strict hardening — non-root, dropped caps, seccomp, read-only FS | Security-sensitive apps, multi-tenant clusters |

This exercise targets the **`restricted`** profile.

---

## Enforcing PSA on the Namespace

```bash
kubectl label namespace dev \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/audit=restricted
```

Three label modes can be set independently:

| Mode | Effect |
|---|---|
| `enforce` | API server **rejects** non-compliant Pods at creation time |
| `warn` | Allows creation but returns a warning message to the client |
| `audit` | Allows creation and logs a violation in the audit log |

Setting all three gives both hard rejection and an audit trail.

---

## Violation-by-Violation Breakdown

### ❌ → ✅ Violation 1 — `hostNetwork: true`

| | bad-pod | restricted-pod |
|---|---|---|
| Setting | `hostNetwork: true` | Omitted (default `false`) |

**Risk:** The Pod shares the node's network namespace — it can listen on any host port, sniff raw traffic from other Pods, and bypass Kubernetes NetworkPolicies entirely (NetworkPolicy operates on the Pod network, not the host network).

**Fix:** Remove the field. The Pod gets its own isolated network namespace via the CNI plugin.

---

### ❌ → ✅ Violation 2 — `hostPID: true`

| | bad-pod | restricted-pod |
|---|---|---|
| Setting | `hostPID: true` | Omitted (default `false`) |

**Risk:** The container can see every process running on the node (via `/proc`). Combined with `SYS_PTRACE`, this allows attaching a debugger to any host process — kubelet, container runtime, other tenant workloads — enabling full credential and secret extraction.

**Fix:** Remove the field. The Pod gets an isolated PID namespace.

---

### ❌ → ✅ Violation 3 — `hostIPC: true`

| | bad-pod | restricted-pod |
|---|---|---|
| Setting | `hostIPC: true` | Omitted (default `false`) |

**Risk:** Exposes node-level POSIX shared memory and semaphores. An attacker can read or corrupt IPC data from other host processes, including container runtime internals.

**Fix:** Remove the field.

---

### ❌ → ✅ Violation 4 — `privileged: true`

| | bad-pod | restricted-pod |
|---|---|---|
| Setting | `privileged: true` | `privileged: false` |

**Risk:** A privileged container receives **all** Linux capabilities and can directly access `/dev` devices, load kernel modules, modify iptables rules, and interact with the container runtime socket. This is functionally equivalent to running as root on the node itself. CVE exploitation inside a privileged container is a trivial node escape.

**Fix:** `privileged: false`. If specific capabilities are genuinely needed (e.g., `NET_BIND_SERVICE` to bind port 80), add only that one capability explicitly.

---

### ❌ → ✅ Violation 5 — Running as root (`runAsUser: 0`)

| | bad-pod | restricted-pod |
|---|---|---|
| `runAsNonRoot` | `false` | `true` (pod + container level) |
| `runAsUser` | `0` (root) | `10001` |
| `runAsGroup` | unset | `10001` |

**Risk:** If a process running as UID 0 escapes the container namespace (via a kernel CVE or runtime bug), the attacker immediately has root on the node. Root inside a container is not meaningfully isolated from root outside without seccomp and AppArmor.

**Fix:** `runAsNonRoot: true` causes admission to reject the Pod if the container image's USER is root. `runAsUser: 10001` explicitly sets a non-root UID. Setting both at pod and container level provides defense-in-depth.

> **Important:** Your container image must be built with a non-root user in the Dockerfile:
> ```dockerfile
> RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
> USER appuser   # or USER 10001
> ```

---

### ❌ → ✅ Violation 6 — `allowPrivilegeEscalation: true`

| | bad-pod | restricted-pod |
|---|---|---|
| Setting | `true` (default) | `false` |

**Risk:** Allows child processes to acquire more privileges than the parent via setuid binaries (e.g., `sudo`, `su`, `passwd`) or file capabilities. Even a non-root process could escalate to root inside the container this way.

**Fix:** `allowPrivilegeEscalation: false` sets the `no_new_privs` bit on the process. After this, `execve()` cannot grant additional capabilities — setuid bits are ignored for privilege purposes.

---

### ❌ → ✅ Violation 7 — Capabilities not dropped (`NET_ADMIN`, `SYS_PTRACE` added)

| | bad-pod | restricted-pod |
|---|---|---|
| `capabilities.drop` | nothing | `["ALL"]` |
| `capabilities.add` | `NET_ADMIN`, `SYS_PTRACE` | nothing |

**Risk:** The default Docker capability set includes 14 capabilities. `NET_ADMIN` allows firewall rule manipulation, interface configuration, and ARP spoofing. `SYS_PTRACE` allows attaching a debugger to any process in the PID namespace — when combined with `hostPID`, to any process on the node.

**Fix:** `drop: ["ALL"]` removes the entire default set. Add back only what the application genuinely requires. For most HTTP/gRPC services running on a high port: nothing.

Common capabilities and when you'd actually need them:

| Capability | Legitimate use | Risk if abused |
|---|---|---|
| `NET_BIND_SERVICE` | Bind port < 1024 | Low — only port binding |
| `NET_ADMIN` | Network interface config | High — iptables, routing |
| `SYS_PTRACE` | Debugger, profiler | Critical — process inspection |
| `SYS_ADMIN` | Many admin ops | Critical — near-privileged equiv |
| `CHOWN` | Change file ownership | Medium — file permission bypass |

---

### ❌ → ✅ Violation 8 — No `readOnlyRootFilesystem`

| | bad-pod | restricted-pod |
|---|---|---|
| `readOnlyRootFilesystem` | `false` (default) | `true` |

**Risk:** A writable root filesystem allows an attacker to drop binaries, modify application config, install persistence mechanisms (cron, rc.d), and create new setuid executables.

**Fix:** `readOnlyRootFilesystem: true`. Any writes the application genuinely needs are redirected to `emptyDir` volumes mounted at specific paths (e.g., `/tmp`, `/var/cache`). This is a design forcing function — it makes all write paths explicit and intentional.

---

### ❌ → ✅ Violation 9 — `hostPath` volume mounting node root `/`

| | bad-pod | restricted-pod |
|---|---|---|
| Volume type | `hostPath: path: /` | `emptyDir: {}` |

**Risk:** Mounting `/` from the host gives the container full read (and in this case write) access to the node's filesystem — SSH keys, kubelet credentials, `/etc/shadow`, container runtime socket (`/run/containerd/containerd.sock`), and etcd data. Writing to the host filesystem is a permanent node compromise that survives Pod deletion.

**Fix:** `emptyDir: {}` is Pod-scoped, cleaned up on Pod deletion, and never touches the node's real filesystem. For persistent storage, use a PVC backed by a CSI driver (which enforces its own access controls).

---

### ✅ New addition — `seccompProfile: RuntimeDefault`

| | bad-pod | restricted-pod |
|---|---|---|
| `seccompProfile` | unset (Unconfined) | `RuntimeDefault` |

**What it does:** The seccomp (secure computing mode) filter restricts which Linux syscalls the process can make. `RuntimeDefault` uses the container runtime's built-in allowlist (containerd/Docker ship one that blocks ~300 dangerous or unnecessary syscalls, including `ptrace`, `kexec_load`, `mount`, `reboot`, and others).

**Why it matters:** Many container escape CVEs rely on obscure syscalls (e.g., `unshare`, `keyctl`, `bpf`). Blocking them at the kernel level provides a defense layer that works even when application-level mitigations fail.

The `restricted` PSS profile **requires** either `RuntimeDefault` or `Localhost` (a custom profile). `Unconfined` is rejected.

---

## Observed Rejection — What You'll See

After labelling the namespace for `enforce=restricted`:

```bash
kubectl apply -f bad-pod.yaml
```

```
Error from server (Forbidden): error when creating "bad-pod.yaml":
pods "bad-pod" is forbidden: violates PodSecurity "restricted:latest":
  privileged (container "bad-container" must not set securityContext.privileged=true),
  host namespaces (hostNetwork=true, hostPID=true, hostIPC=true must all be false),
  allowPrivilegeEscalation != false (container "bad-container" must set
    securityContext.allowPrivilegeEscalation=false),
  unrestricted capabilities (container "bad-container" must set
    securityContext.capabilities.drop=["ALL"]),
  runAsNonRoot != true (pod or container "bad-container" must set
    securityContext.runAsNonRoot=true),
  seccompProfile (pod or container "bad-container" must set
    securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost"),
  hostPath volumes (volume "host-root" must not use hostPath)
```

The API server rejects the entire Pod in a single atomic operation — nothing is created. All violations are listed together so you can fix them in one pass.

```bash
kubectl apply -f restricted-pod.yaml
```

```
pod/restricted-pod created
```

---

## Summary Table

| Violation | bad-pod | restricted-pod | Risk eliminated |
|---|---|---|---|
| `hostNetwork` | `true` | `false` | Node traffic sniffing, NetworkPolicy bypass |
| `hostPID` | `true` | `false` | Host process inspection, ptrace attacks |
| `hostIPC` | `true` | `false` | Host IPC exploitation |
| `privileged` | `true` | `false` | Full node access, device access |
| `runAsUser` | `0` (root) | `10001` | Root escape blast radius |
| `runAsNonRoot` | `false` | `true` | Accidental root image use |
| `allowPrivilegeEscalation` | `true` | `false` | Setuid/capability escalation |
| `capabilities` | `NET_ADMIN`, `SYS_PTRACE` added | all dropped, none added | Interface manipulation, process inspection |
| `readOnlyRootFilesystem` | `false` | `true` | Binary drop, persistence |
| Volume type | `hostPath: /` | `emptyDir` | Node filesystem access |
| `seccompProfile` | Unconfined | `RuntimeDefault` | Kernel syscall exploitation |
