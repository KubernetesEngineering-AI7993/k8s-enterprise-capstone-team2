# Lab 03 - Image Scanning with Trivy

## Objective
Scan container images for known vulnerabilities using Trivy, compare results between image tags, integrate scanning into a CI pipeline, and understand shift-left security.

## What is Trivy?

Trivy is an open-source security scanner from Aqua Security that checks container images for known vulnerabilities. Every container image is built on layers of software (operating system, libraries, packages). If any of those packages have known security bugs (CVEs), Trivy finds them and reports the severity.

## What We Did

### Scanned nginx:latest
Ran trivy image nginx:latest to scan the latest nginx image. Results: 156 total vulnerabilities (0 CRITICAL, 4 HIGH, 24 MEDIUM, 126 LOW, 2 UNKNOWN). The latest tag has the most recent security patches, so fewer critical issues.

### Scanned nginx:1.27 (our pinned version)
Ran trivy image nginx:1.27 to scan the version we have been using throughout the course. Results: 268 total vulnerabilities (7 CRITICAL, 39 HIGH, 72 MEDIUM, 145 LOW, 5 UNKNOWN). More vulnerabilities because this is an older image that has accumulated unpatched security issues.

### Key Insight: Pinned vs Latest
This seems counterintuitive. We have been told to pin versions and avoid latest. The lesson is: pin to a specific version for stability (so your app does not break when the image changes unexpectedly), but regularly update that pinned version for security. You do not want latest because it can change without warning. But you also cannot stay on an old version forever.

The real-world practice: pin your version, scan it regularly, and update when vulnerabilities are found.

### Created CI Pipeline Snippet
Created trivy-ci-snippet.yaml that integrates Trivy into a GitHub Actions pipeline. The key flag is --exit-code 1 --severity CRITICAL, which causes the pipeline to fail if any CRITICAL vulnerabilities are found. This blocks deployment of insecure images automatically.

## What is Shift-Left Security?

Traditional security checks happen at the end. This is after code is written, after images are built, after deployment. By then, fixing issues is expensive and slow.

Shift-left means moving security checks earlier in the process:
- Scan images in the CI pipeline before they are deployed
- Fail the build if critical vulnerabilities are found
- Developers fix issues before code reaches production

Trivy in CI is a shift-left practice. Instead of discovering a vulnerable image in production (where it is already serving users), you catch it during the PR review (before it is ever deployed).

## Vulnerability Severity Levels

- CRITICAL: actively exploitable, immediate risk, must fix before deploying
- HIGH: serious risk, should fix soon
- MEDIUM: moderate risk, fix in normal development cycle
- LOW: minor risk, fix when convenient
- UNKNOWN: severity not yet classified

## Trivy CI Integration

The pipeline snippet uses --exit-code 1 to fail the pipeline on CRITICAL findings. This means:
- Developer pushes code with a Dockerfile
- CI pipeline builds the image
- Trivy scans the built image
- If CRITICAL vulnerabilities found: pipeline FAILS, PR gets red X, deployment blocked
- If no CRITICAL vulnerabilities: pipeline passes, deployment proceeds

## Vulnerability Management Best Practices

- Pin image versions but update regularly
- Scan images in CI on every PR
- Fail builds on CRITICAL and HIGH vulnerabilities
- Use minimal base images (alpine variants have fewer packages = fewer vulnerabilities)
- Rebuild images regularly to pick up OS security patches
- Monitor deployed images for newly discovered vulnerabilities

## Deliverables
- trivy-scan-latest.txt: full Trivy scan output for nginx:latest
- trivy-scan-pinned.txt: full Trivy scan output for nginx:1.27
- trivy-ci-snippet.yaml: GitHub Actions pipeline with Trivy scan stage
- lab03.txt: summary evidence
- lab03_notes.md: this file
