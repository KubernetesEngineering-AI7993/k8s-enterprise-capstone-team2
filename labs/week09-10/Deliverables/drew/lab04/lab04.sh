# Lab 04 - Deployment Validation

# Run validation against bad deployment (should fail)
powershell -ExecutionPolicy Bypass -File validate-deployment.ps1 bad-deployment.yaml

# Run validation against good deployment (should pass)
powershell -ExecutionPolicy Bypass -File validate-deployment.ps1 good-deployment.yaml