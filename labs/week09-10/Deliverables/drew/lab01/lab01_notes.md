# Lab 01 - GitOps Using ArgoCD

## Objective
Install ArgoCD in the cluster, create an Application pointing to a git repo, enable auto-sync, observe auto-deployment on git changes, and demonstrate self-healing drift reconciliation.

## What is GitOps?

GitOps is a deployment model where git is the single source of truth for what should be running in your cluster. Instead of manually running kubectl apply from your laptop, you install a tool (ArgoCD) inside the cluster that watches your git repo and automatically applies any changes it detects.

The core principle: you never touch the cluster directly. You push changes to git, and the cluster syncs itself. If someone manually changes the cluster, ArgoCD detects the drift and reverts it to match git.

## What We Did

### Installed ArgoCD
Created an argocd namespace and installed ArgoCD using the official manifests. ArgoCD runs as several pods in the cluster: an API server, an application controller, a repo server, a Redis cache, and others. Accessed the dashboard via port-forward on port 8080.

### Created an ArgoCD Application (argocd-app.yaml)
The Application resource tells ArgoCD three things:
- Source: watch the drew/week09-10 branch at labs/week09-10/Deliverables/drew/lab01/
- Destination: deploy to the default namespace in the local cluster
- Sync policy: automated with selfHeal and prune enabled

ArgoCD read the deployment.yaml from git and created the gitops-demo Deployment with 2 replicas automatically. We never ran kubectl apply for the deployment — ArgoCD did it.

### Demonstrated Auto-Sync
Changed replicas from 2 to 3 in deployment.yaml, committed, and pushed to git. Within seconds, ArgoCD detected the change and scaled the deployment to 3 pods. The cluster automatically reflected the git change without any manual intervention.

### Demonstrated Self-Healing (Drift Reconciliation)
Manually ran kubectl scale deployment gitops-demo --replicas=1 to create drift between the cluster (1 replica) and git (3 replicas). ArgoCD detected the drift almost instantly and scaled back to 3 replicas. Git always wins.

## GitOps Workflow

1. Developer edits YAML in git (e.g., change replicas, update image tag)
2. Developer commits and pushes to the branch
3. ArgoCD detects the change (polls every 3 minutes, or faster with webhooks)
4. ArgoCD compares git state vs cluster state
5. If different, ArgoCD applies the git version to the cluster
6. If someone manually changes the cluster, selfHeal reverts it to match git

## Key Configuration in argocd-app.yaml

- repoURL: the git repository ArgoCD watches
- targetRevision: which branch to track
- path: which folder contains the manifests
- automated: enables auto-sync (no manual sync button needed)
- selfHeal: reverts manual cluster changes to match git
- prune: deletes cluster resources when their YAML is removed from git

## Why GitOps Matters

- Single source of truth: git always reflects what should be running
- Audit trail: every change is a git commit with author, timestamp, and message
- No manual kubectl: prevents undocumented changes to the cluster
- Self-healing: manual drift is automatically corrected
- Rollback: revert a git commit and the cluster reverts too

## Deliverables
- deployment.yaml: nginx Deployment managed by ArgoCD
- argocd-app.yaml: ArgoCD Application manifest
- lab01.txt: output evidence (deployments, pods, application status)
- lab01_notes.md: this file
