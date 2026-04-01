# Lab 03 – Image Scanning with Trivy: Notes & Vulnerability Management

---

## What is Trivy?

Trivy is an open-source vulnerability scanner by Aqua Security. It scans container
images, filesystems, Git repos, and Kubernetes clusters for known CVEs, misconfigurations,
exposed secrets, and software license issues. It uses the NVD, OS vendor advisories,
and language-specific package databases (Go, npm, pip, Maven, etc.) as its sources.

**Shift-left security** means running these checks as early as possible in the
development lifecycle — in CI, before an image is pushed to a registry or deployed
to a cluster — rather than detecting vulnerabilities only after they reach production.

Install Trivy:

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sudo sh -s -- -b /usr/local/bin v0.69.3
```

---

## Scan Results Summary

### adguard/adguardhome:v0.107.53

| Layer | CRITICAL | HIGH | Notes |
|---|---|---|---|
| Alpine 3.18.9 (OS) | 0 | 2 | `musl`/`musl-utils` — CVE-2025-26519, fix available |
| AdGuardHome binary (Go) | 2 | 7 | Vendored Go deps — fix requires newer AdGuard build |
| **Total** | **2** | **9** | |

**Critical findings in the Go binary:**

- `CVE-2024-45337` — `golang.org/x/crypto/ssh` authorization bypass. Fixed in `v0.31.0`
  (AdGuard ships `v0.26.0`). An attacker could bypass SSH public key authentication.
- `CVE-2025-68121` — `crypto/tls` unexpected session resumption in Go stdlib `v1.23.2`.
  Fixed in `v1.24.13`. Could allow unintended TLS session reuse.

**Remediation:** Upgrade to a newer AdGuard Home release that vendors updated Go
dependencies. The Alpine OS vulnerabilities can be addressed with `apk upgrade` in a
custom image build.

---

### nginx:latest (Debian 13.4)

| Layer | CRITICAL | HIGH | Notes |
|---|---|---|---|
| Debian OS packages | 0 | 16 | Mostly `affected` — no fix available yet |
| **Total** | **0** | **16** | |

**Notable findings:**

- `CVE-2026-4046` — `glibc` denial of service via `iconv()` — `fix_deferred` (Debian
  has not yet shipped a fix)
- `CVE-2026-33416` / `CVE-2026-33636` — `libpng` use-after-free and out-of-bounds
  read/write — `fixed`, upgrade available
- `CVE-2026-29111` — `systemd` arbitrary code execution via IPC — `affected`, no fix

**Key insight:** Most nginx findings are `fix_deferred` or `affected` with no fix
version. This is common with `latest` tags on Debian-based images — the OS vendor
hasn't shipped patches yet. This is why pinning image versions is important: `nginx:latest`
will silently pick up new vulnerabilities as the base OS changes.

---

## The --exit-code Flag: Why It Matters

By default, Trivy always exits with code `0` regardless of findings. This means a
naive CI pipeline integration that just runs `trivy image nginx:latest` will always
"pass" even if critical vulnerabilities are found.

```bash
# Wrong — never fails the pipeline
trivy image --severity CRITICAL,HIGH nginx:latest
echo $?  # Always 0

# Correct — fails pipeline when findings exist
trivy image --severity CRITICAL,HIGH --exit-code 1 nginx:latest
echo $?  # 1 if findings, 0 if clean
```

The CI pipeline in `trivy-scan.yaml` uses `--exit-code 1` for the AdGuard scan
(blocking) and `--exit-code 0` for the nginx scan (warn-only), demonstrating both
patterns.

---

## Integrating Trivy into a Gitea Actions Pipeline

The pipeline in `.gitea/workflows/trivy-scan.yaml` has two jobs:

**`scan-adguard`** — Blocking scan. Uses `--exit-code 1`. If CRITICAL or HIGH
vulnerabilities are found, the job fails and the pipeline stops. This enforces a
hard gate: no deployment proceeds until the image is clean or vulnerabilities are
explicitly acknowledged.

**`scan-nginx`** — Warn-only scan. Uses `--exit-code 0`. Findings are reported and
saved as artifacts but the pipeline continues. Use this pattern for third-party images
you don't control where fixing isn't immediately possible.

```yaml
# Blocking (fail on findings)
- name: Fail pipeline on CRITICAL or HIGH
  run: |
    trivy image \
      --severity CRITICAL,HIGH \
      --exit-code 1 \
      adguard/adguardhome:v0.107.53

# Non-blocking (warn only)
- name: Scan for awareness only
  run: |
    trivy image \
      --severity CRITICAL,HIGH \
      --exit-code 0 \
      nginx:latest
```

---

## Vulnerability Status Values

Trivy reports a `Status` field for each finding — understanding it determines
whether action is possible:

| Status | Meaning | Action |
|---|---|---|
| `fixed` | A patched version exists | Upgrade the package |
| `fix_deferred` | Vendor acknowledged, fix not yet shipped | Monitor, consider workaround |
| `affected` | Confirmed vulnerable, no fix available | Accept risk or replace image |
| `will_not_fix` | Vendor won't patch (EOL, low priority) | Replace image or mitigate |
| `under_investigation` | Still being analysed | Monitor |

---

## Best Practices for Vulnerability Management

**1. Pin image versions — never use `latest` in production.**
`nginx:latest` changes silently. A pinned tag like `nginx:1.27.4` gives you a
reproducible, scannable surface. Pair with a tool like Renovate or Dependabot to
automate version bump PRs.

**2. Scan at every stage.**
- Developer laptop: `trivy image` before pushing
- CI pipeline: block merges on new CRITICAL/HIGH findings
- Registry: scan on push (Trivy has a Harbor plugin)
- Runtime: periodic re-scans since new CVEs are published daily

**3. Use `--ignore-unfixed` to reduce noise.**
When a finding has no fix available, failing the pipeline on it creates friction
without a remediation path. `--ignore-unfixed` skips `affected` and `fix_deferred`
findings, keeping the pipeline actionable.

```bash
trivy image \
  --severity CRITICAL,HIGH \
  --ignore-unfixed \
  --exit-code 1 \
  adguard/adguardhome:v0.107.53
```

**4. Use `.trivyignore` to acknowledge accepted risks.**
For findings you've reviewed and accepted (e.g. a CVE in a component not reachable
in your deployment), add the CVE ID to `.trivyignore` with a comment explaining the
decision. This keeps the pipeline clean without silencing new unknown findings.

```
# .trivyignore
# CVE-2024-45337: SSH component not used in AdGuard Home deployment
CVE-2024-45337
```

**5. Separate OS and app-layer findings.**
OS package vulnerabilities (Alpine, Debian) are fixed by rebuilding the image with
updated base packages. Go/Node/Python dependency vulnerabilities require the upstream
project to update their vendored deps and cut a new release — you can't fix them
yourself without forking.

**6. Set a meaningful severity threshold.**
CRITICAL+HIGH is a sensible default for blocking pipelines. MEDIUM findings are
common and often have low exploitability — failing on them creates alert fatigue.
Reserve MEDIUM scanning for periodic audits rather than every commit.

---

## AdGuard Home: Recommended Remediation

Given the 2 CRITICAL and 7 HIGH findings in `v0.107.53`:

1. Check the AdGuard Home releases page for a version that vendors
   `golang.org/x/crypto >= 0.31.0` and `stdlib >= 1.24.13`
2. Update `helm/adguard-home/values.yaml` — change `tag: v0.107.53` to the newer tag
3. Re-scan the new image: `trivy image --severity CRITICAL,HIGH adguard/adguardhome:<new-tag>`
4. Commit the tag bump — ArgoCD will auto-sync and deploy the patched version

This is the GitOps + shift-left loop working end-to-end: scan in CI catches the
vulnerability, a Git commit to update the image tag triggers ArgoCD to deploy the fix.
