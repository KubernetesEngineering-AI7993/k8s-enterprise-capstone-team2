# Lab 04 – Troubleshooting Failing Workloads

## Goal
Practice troubleshooting loop using common failure modes:
- CrashLoopBackOff
- ImagePullBackOff
- Pending pods
- Service selector mismatch

## My troubleshooting checklist 
1) `kubectl get` → what is the status?
2) `kubectl describe` → WHY (events at the bottom are the best clue)
3) `kubectl logs` → what did the container say?
4) `kubectl get events` → timeline of what happened

## Scenario 1: CrashLoopBackOff
- Symptom: pod keeps restarting.
- Cause: container command/app exits immediately.
- Proof: `describe` shows CrashLoopBackOff, logs show the app exiting.
- Fix: change the command/app so it stays running.

## Scenario 2: ImagePullBackOff
- Symptom: pod stuck with ErrImagePull/ImagePullBackOff.
- Cause: bad image name/tag or registry auth issue.
- Proof: Events show failed pull + back-off.
- Fix: correct the image tag/name, recreate pod.

## Scenario 3: Pending Pod
- Symptom: pod never starts, stays Pending.
- Cause: scheduler can’t find a node that matches the requirements.
- Proof: Events shows FailedScheduling events.
- Fix: correct nodeSelector.

## Scenario 4: Service selector mismatch
- Symptom: service exists but traffic goes nowhere.
- Cause: service selector doesn’t match pod labels → endpoints empty.
- Proof: `kubectl get endpoints` or `endpointslice` shows none.
- Fix: change service selector to match pod labels .

## Key takeaway
Most Kubernetes issues are solved by reading Events in `describe` and confirming label/selector matches for Services.
