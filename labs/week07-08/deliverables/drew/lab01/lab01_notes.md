# Lab 01 - Helm Charts

## Objective
Create a Helm chart for an existing application, parameterize key values, install and upgrade the release, and roll back to a previous revision.

## What We Did

### Created a Helm Chart
Used helm create sample-app to scaffold a complete chart. This generated:
- Chart.yaml: metadata (name, version, description)
- values.yaml: default configuration values
- templates/: Kubernetes YAML files with placeholders
- templates/deployment.yaml, service.yaml, serviceaccount.yaml, etc.

### Parameterized Key Values
The values.yaml file controls three key settings (among others):
- replicaCount: 1 (number of Pods)
- image.tag: "1.27" (container image version)
- service.type: ClusterIP (how the Service is exposed)

These values feed into the templates via {{ .Values.replicaCount }}, {{ .Values.image.tag }}, etc. Changing values.yaml or using --set flags changes the output without editing any template.

### Installed the Chart
Used helm install sample-app ./sample-app to deploy the app. Helm read the values, filled in the templates, and applied the resulting YAML to Kubernetes. This created a Deployment, Service, and ServiceAccount as REVISION 1.

### Upgraded the Release
Used helm upgrade sample-app ./sample-app --set replicaCount=2 to scale to 2 replicas. Helm figured out what changed and updated only the Deployment. This became REVISION 2.

### Rolled Back
Used helm rollback sample-app 1 to revert to the original configuration (1 replica). Helm created REVISION 3 with the settings from REVISION 1. The rollback was instant.

## Explaining values.yaml

values.yaml is the configuration file for a Helm chart. It contains default values for every variable used in the templates. Think of it as a form you fill out to customize the deployment.

Key values in our chart:
- replicaCount: how many Pods the Deployment runs
- image.repository: which container image to use (nginx)
- image.tag: which version of that image (1.27)
- image.pullPolicy: when to pull the image (IfNotPresent)
- service.type: how the Service is exposed (ClusterIP, NodePort, LoadBalancer)
- service.port: which port the Service listens on (80)
- livenessProbe / readinessProbe: health check configuration

You can override any value at install or upgrade time using --set flags without editing the file. This means one chart can be deployed to multiple environments (dev, staging, production) with different settings.

## Templates vs Raw YAML

Raw YAML (what we wrote in Week 05-06):
- Every value is hardcoded: replicas: 2, image: nginx:1.27
- To change a value, you edit the file directly
- To deploy to a different environment, you copy the file and edit the copy
- 10 microservices x 3 environments = 30+ files to maintain

Helm Templates:
- Values are placeholders: replicas: {{ .Values.replicaCount }}
- To change a value, you edit values.yaml or use --set
- To deploy to a different environment, you pass different values to the same template
- 10 microservices x 3 environments = 10 charts with 3 values files

Templates also support conditional logic ({{- if }}), loops ({{- range }}), and helper functions ({{- include }}) for more complex configurations. But the core idea is simple: separate what changes (values) from what stays the same (templates).

## Rollback Behavior

Helm tracks every install and upgrade as a numbered revision:
- REVISION 1: helm install (initial deployment)
- REVISION 2: helm upgrade (changed replicaCount to 2)
- REVISION 3: helm rollback to 1 (reverted to original settings)

Key behaviors:
- Rollbacks create a NEW revision (rollback to rev 1 created rev 3, not overwriting rev 2)
- helm history sample-app shows the full revision history with timestamps and status
- You can rollback to any previous revision with helm rollback RELEASE REVISION_NUMBER
- The rollback applies the exact same values and templates from the target revision
- Kubernetes handles the actual Pod replacement using its normal rolling update mechanism

This is safer than manual rollbacks with kubectl because Helm tracks the complete state of every revision. With raw YAML, you would need to remember which files to revert and re-apply them manually.

## Helm Release History
REVISION 1: Install complete (1 replica, nginx:1.27, ClusterIP)
REVISION 2: Upgrade complete (2 replicas)
REVISION 3: Rollback to 1 (1 replica)

## Deliverables
- sample-app/ directory (the complete Helm chart)
- lab01.sh: commands used throughout the lab
- lab01.txt: output evidence (helm list, history, pods, services)
- lab01_notes.md: this file
