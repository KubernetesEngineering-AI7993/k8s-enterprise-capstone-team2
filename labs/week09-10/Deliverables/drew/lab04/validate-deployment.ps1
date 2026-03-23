# Deployment Validation Script (PowerShell)
# Checks Kubernetes manifests for common misconfigurations

param([string]$File)

if (-not $File) {
    Write-Host "Usage: .\validate-deployment.ps1 <yaml-file>"
    exit 1
}

$content = Get-Content $File -Raw
$errors = 0

Write-Host "Validating: $File"
Write-Host "================================"

# Check 1: Use of :latest tag or no tag
if ($content -match "image:.*:latest" -or $content -match "image:\s+[a-zA-Z]+\s*$") {
    Write-Host "FAIL: Image uses :latest tag or no tag specified" -ForegroundColor Red
    Write-Host "  Fix: Pin to a specific version (nginx:1.27)"
    $errors++
} else {
    Write-Host "PASS: Image tag is pinned" -ForegroundColor Green
}

# Check 2: Missing resource limits
if ($content -notmatch "limits:") {
    Write-Host "FAIL: No resource limits defined" -ForegroundColor Red
    Write-Host "  Fix: Add resources.limits.cpu and resources.limits.memory"
    $errors++
} else {
    Write-Host "PASS: Resource limits defined" -ForegroundColor Green
}

# Check 3: Missing resource requests
if ($content -notmatch "requests:") {
    Write-Host "FAIL: No resource requests defined" -ForegroundColor Red
    Write-Host "  Fix: Add resources.requests.cpu and resources.requests.memory"
    $errors++
} else {
    Write-Host "PASS: Resource requests defined" -ForegroundColor Green
}

# Check 4: Missing liveness probe
if ($content -notmatch "livenessProbe:") {
    Write-Host "FAIL: No liveness probe defined" -ForegroundColor Red
    Write-Host "  Fix: Add a livenessProbe to detect container failures"
    $errors++
} else {
    Write-Host "PASS: Liveness probe defined" -ForegroundColor Green
}

# Check 5: Missing readiness probe
if ($content -notmatch "readinessProbe:") {
    Write-Host "FAIL: No readiness probe defined" -ForegroundColor Red
    Write-Host "  Fix: Add a readinessProbe to control traffic flow"
    $errors++
} else {
    Write-Host "PASS: Readiness probe defined" -ForegroundColor Green
}

Write-Host "================================"
if ($errors -gt 0) {
    Write-Host "RESULT: $errors validation error(s) found. Deployment blocked." -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: All checks passed. Safe to deploy." -ForegroundColor Green
    exit 0
}