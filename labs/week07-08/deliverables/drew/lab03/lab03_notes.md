# Lab 03 - CI Pipeline



## Objective

Create a CI pipeline using GitHub Actions that validates YAML, builds a container image, and deploys to Kubernetes.



## Pipeline Stages Explained



### Stage 1: Checkout Code

Uses actions/checkout@v4 to pull the repository code into the pipeline runner. Every CI pipeline starts with this — the runner is a fresh virtual machine that has nothing on it until you check out your code.



### Stage 2: Validate YAML Files

Loops through all YAML files in the deliverables folders and validates them using Python's yaml.safe_load. If a file has invalid YAML (bad indentation, missing colons, tabs instead of spaces), this stage catches it before deployment. In a real pipeline, you might also use kubeval or kubeconform to validate against the Kubernetes API schema.



### Stage 3: Build Container Image (Mock)

In a real pipeline, this would run docker build to create a container image from a Dockerfile, then push it to a container registry (Docker Hub, AWS ECR, GitHub Container Registry). We mock this step because we don't have a Dockerfile or registry set up. The important concept is that CI builds a fresh image for every change.



### Stage 4: Deploy to Kubernetes (Mock)

In a real pipeline, this would run kubectl apply or helm upgrade to deploy the new image to a cluster. This requires cluster credentials stored as GitHub Secrets. We mock this because our kind cluster is local and not accessible from GitHub's runners. In production, this step would connect to a cloud cluster (EKS, GKE, AKS).



## Trigger

The pipeline triggers on pull_request to main or week07-08 branches. This means every PR gets validated before merging — catching errors early.



## What Could Be Added in Production

- Linting with kubeval/kubeconform for K8s schema validation

- Unit tests for application code

- Security scanning (Trivy for container vulnerabilities)

- Slack/Teams notifications on failure

- Separate stages for staging vs production deployment

- Manual approval gate before production deploy



## Deliverables

- ci-pipeline.yaml: GitHub Actions workflow file

- lab03_notes.md: explanation of pipeline stages

