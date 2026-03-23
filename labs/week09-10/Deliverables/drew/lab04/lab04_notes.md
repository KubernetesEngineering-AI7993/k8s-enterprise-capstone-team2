# Lab 04 - Deployment Validation

## Objective
Create validation rules that check Kubernetes manifests for common misconfigurations before deployment, demonstrate blocking an invalid deployment, and explain the validation logic.

## What is Deployment Validation?

Image scanning catches vulnerabilities in the software inside your containers. Deployment validation catches a different category of problems: misconfigurations in how you deploy those containers. These are not security bugs in code (they are bad practices that cause outages and instability).

Examples of misconfigurations that cause real production incidents:
- No resource limits: one container eats all the node's memory, crashing everything else
- Using :latest tag: image changes unexpectedly, breaking your app without any code change
- Missing health probes: Kubernetes cannot detect when your app is dead or not ready
- Missing resource requests: scheduler cannot make good decisions about where to place Pods

## What We Did

### Created a Validation Script (validate-deployment.ps1)
Built a PowerShell script that checks five common misconfigurations:
1. Image uses :latest tag or no tag (unpredictable deployments)
2. Missing resource limits (container can consume unlimited resources)
3. Missing resource requests (scheduler cannot plan placement)
4. Missing liveness probe (Kubernetes cannot detect dead containers)
5. Missing readiness probe (traffic sent to containers that are not ready)

Each check prints PASS or FAIL with a description of how to fix the issue. The script exits with code 1 if any checks fail, which can be used in CI to block deployment.

### Tested Against a Bad Deployment (bad-deployment.yaml)
Created a deliberately misconfigured Deployment: nginx:latest with no resource limits, no requests, and no probes. The validation script caught all 5 issues and returned "Deployment blocked."

### Tested Against a Good Deployment (good-deployment.yaml)
Created a properly configured Deployment: nginx:1.27 with resource requests and limits, plus liveness and readiness probes. The validation script returned "All checks passed. Safe to deploy."

## Validation Rules Explained

### Rule 1: No :latest Tag
The :latest tag points to whatever the newest image happens to be. If someone pushes a new version to the registry, your next Pod restart pulls a completely different image without any code change on your side. Pinning to a specific version (nginx:1.27) ensures you always know exactly what is running.

### Rule 2: Resource Limits Required
Without limits, a container can use unlimited CPU and memory. One misbehaving container can consume all resources on a node, causing every other Pod on that node to crash or become unresponsive. Limits set a ceiling: the container is killed if it exceeds them (OOMKilled for memory).

### Rule 3: Resource Requests Required
Requests tell the Kubernetes scheduler how much CPU and memory a Pod needs. Without requests, the scheduler places Pods blindly. It might put 20 memory-heavy Pods on a node that cannot handle them. Requests enable intelligent scheduling decisions.

### Rule 4: Liveness Probe Required
Without a liveness probe, Kubernetes only knows if the container process is running  (not if the application is actually working). A deadlocked app with a running process looks healthy to Kubernetes. The liveness probe detects this and triggers a restart.

### Rule 5: Readiness Probe Required
Without a readiness probe, Kubernetes sends traffic to a Pod as soon as its container starts. If the app takes 30 seconds to load data, users get errors for those 30 seconds. The readiness probe tells Kubernetes to wait until the app is actually ready before sending traffic.

## How This Fits Into CI/CD

In production, this validation script would run as a step in the CI pipeline:
1. Developer pushes a Deployment YAML
2. CI validates YAML syntax (Lab 03 from Week 07-08)
3. CI runs Trivy image scan (Lab 03 from this week)
4. CI runs deployment validation (this lab)
5. If all pass: deployment proceeds
6. If any fail: PR gets red X, deployment blocked

Each layer catches a different category of problem: syntax errors, image vulnerabilities, and deployment misconfigurations.

## Deliverables
- validate-deployment.ps1: validation script with 5 checks
- bad-deployment.yaml: intentionally misconfigured Deployment (all checks fail)
- good-deployment.yaml: properly configured Deployment (all checks pass)
- lab04.txt: output evidence showing blocked and passed deployments
- lab04_notes.md: this file
