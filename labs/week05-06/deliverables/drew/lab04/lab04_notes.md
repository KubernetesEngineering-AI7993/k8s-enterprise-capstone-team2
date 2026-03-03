# Lab 04 - Rolling Updates and Rollbacks

## Objective
Perform a rolling update on a Deployment, monitor the rollout in real time, simulate a failed deployment with a bad image, and roll back to the previous working version.

## Cluster Context
Continued using the kind cluster cka-labs05-06 with the labs namespace. Cleaned up Lab 03 deployments before starting to stay within 8GB RAM constraints.

## Task 1 - Create a Deployment with Rolling Update Strategy (probes-and-rolling.yaml)
Created a Deployment called rolling-demo with 2 replicas running nginx:1.26. Key configuration:
- strategy type RollingUpdate with maxSurge 1 and maxUnavailable 0
- maxSurge 1 allows one extra Pod above desired count during updates
- maxUnavailable 0 ensures available Pods never drop below the desired count (zero downtime guarantee)
- Readiness probe on port 80 ensures new Pods only receive traffic once they are actually serving

Verified with kubectl rollout status deployment/rolling-demo which confirmed successful rollout.

## Task 2 - Update Image and Monitor Rollout
Performed two rolling updates to observe the behavior:

Update 1 (nginx:1.26 to nginx:1.27): Used kubectl set image to trigger the update. Completed quickly.

Update 2 (nginx:1.27 back to nginx:1.26): Watched in real time using kubectl get pods -w in a second terminal. Observed the full rolling update sequence:
1. New Pod created: Pending, ContainerCreating, Running
2. Readiness probe passed: Pod became Ready (1/1) after about 10 seconds
3. Only after new Pod was Ready, old Pod started Terminating
4. Second new Pod created, same lifecycle
5. Second old Pod terminated after second new Pod was Ready
6. At no point were there fewer than 2 Ready Pods - zero downtime confirmed

The watch output clearly showed the create-new, wait-for-ready, kill-old pattern that defines rolling updates.

## Task 3 - Failed Deployment and Rollback (fail-rollout.yaml)
Applied a Deployment with a nonexistent image (nginx:99.99.99) to simulate a bad deploy.

Observed behavior (watched in real time with kubectl get pods -w):
- New Pod created but immediately hit ErrImagePull, then ImagePullBackOff
- New Pod never became Ready because the image does not exist
- Old Pods (nginx:1.26) stayed Running at 1/1 the entire time - maxUnavailable 0 protected them
- kubectl rollout status hung waiting for the rollout to complete
- Application continued serving traffic on old Pods despite the completely broken deploy

Rollback with kubectl rollout undo deployment/rolling-demo:
- Bad Pod was immediately terminated
- Old healthy Pods were never touched - they were already running
- kubectl rollout status confirmed successful rollout after undo
- Total application downtime: zero

## Key Concepts
- Rolling updates replace Pods gradually, not all at once
- maxSurge controls how many extra Pods can exist during an update
- maxUnavailable controls the minimum available Pods during an update
- maxUnavailable 0 guarantees zero downtime but makes updates slower
- Readiness probes are critical for rolling updates - they prevent traffic to Pods that are not ready
- kubectl rollout undo instantly reverts to the previous revision
- kubectl rollout history shows all past revisions for a Deployment
- A failed rollout does not take down the existing application when maxUnavailable is 0

## Troubleshooting Notes
- Used two PowerShell windows (kubectl get pods -w in one, commands in the other) to observe rolling updates in real time
- The first rollout status ran before the image update due to command ordering - ran it again after the update completed
- Memory stayed stable throughout Lab 04 since we cleaned up previous lab deployments

## Deliverables
- probes-and-rolling.yaml - Deployment with rolling update strategy and readiness probe
- fail-rollout.yaml - Deployment with bad image (nginx:99.99.99) to trigger failed rollout
- DeploymentNotes.md - Observations on rolling update and rollback behavior
- lab04.sh - Commands used throughout the lab
- lab04.txt - Output evidence (rollout history, pod status, deployment details)
