# Lab 03 - Image Scanning with Trivy

# Download Trivy

# Scan nginx:latest
trivy image nginx:latest > trivy-scan-latest.txt 2>&1

# Scan nginx:1.27 (pinned version)
trivy image nginx:1.27 > trivy-scan-pinned.txt 2>&1

# Compare results
cat trivy-scan-latest.txt | Select-String "Total:"
cat trivy-scan-pinned.txt | Select-String "Total:"

