**Deployment strategy**  
The strategy was to deploy the rolling updates and the app-probes simultaneously to know immediately whether the deployment succeeded.  
**Probe behavior**  
A probe pod was created for each application pod containing logs for the application pod.  
**Rollout and rollback observations**  
The version number for each rollout allows a person to revert a failed rollout to a working rollout  
