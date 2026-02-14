\# Troubleshooting Report

\#\# Issue Summary  
I encountered an OOM-killed condition on my nginx pod.

\#\# Symptoms  
After running the command to create the pod, kubectl top returned "error: metrics not available yet"

\#\# Investigation  
sudo kubectl describe pods resource-demo | grep \-i oom returned:  
"Error: failed to create containerd task: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: container init was OOM-killed (memory limit too low?)"

\#\# Root Cause  
This happened because I set the requested memory and the memory limit to the container to 1Mi, which do not provide enough memory resources for the nginx application to load and run.

\#\# Resolution  
This was fixed by increasing the requested memory to 128Mi and the memory limit to 256Mi which were enough for the nginx application to load and run.  
