MANIFESTS_DIR="${1:-k8s/manifests}"
ERRORS=0
WARNINGS=0

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # no color

echo ""
echo "=============================================="
echo " Kubernetes Manifest Validation"
echo " Scanning: $MANIFESTS_DIR"
echo "=============================================="

# Check the folder exists
if [ ! -d "$MANIFESTS_DIR" ]; then
  echo -e "${RED}ERROR: Directory '$MANIFESTS_DIR' not found.${NC}"
  exit 1
fi

# Collect all YAML files
YAML_FILES=$(find "$MANIFESTS_DIR" -name "*.yaml" -o -name "*.yml")

if [ -z "$YAML_FILES" ]; then
  echo -e "${YELLOW}WARNING: No YAML files found in $MANIFESTS_DIR${NC}"
  exit 0
fi

# Loop over every YAML file
for FILE in $YAML_FILES; do

  # Only validate Deployment and StatefulSet — other kinds skip cleanly
  KIND=$(grep "^kind:" "$FILE" | awk '{print $2}')
  if [[ "$KIND" != "Deployment" && "$KIND" != "StatefulSet" ]]; then
    echo -e "${BLUE}SKIP${NC}  $FILE (kind: ${KIND:-unknown})"
    continue
  fi

  echo ""
  echo "----------------------------------------------"
  echo "Checking: $FILE"
  echo "----------------------------------------------"
  FILE_ERRORS=0

  # ------------------------------------------------------------
  # CHECK 1 — Resource limits (CPU + memory must both be set)
  # ------------------------------------------------------------
  HAS_LIMITS=$(grep -c "limits:" "$FILE")
  HAS_CPU=$(grep -A5 "limits:" "$FILE" | grep -c "cpu:")
  HAS_MEMORY=$(grep -A5 "limits:" "$FILE" | grep -c "memory:")

  if [ "$HAS_LIMITS" -eq 0 ] || [ "$HAS_CPU" -eq 0 ] || [ "$HAS_MEMORY" -eq 0 ]; then
    echo -e "  ${RED}FAIL${NC}  [CHECK 1] Missing resource limits"
    echo "        Every container must define:"
    echo "          resources:"
    echo "            limits:"
    echo "              cpu: \"500m\""
    echo "              memory: \"256Mi\""
    ((ERRORS++))
    ((FILE_ERRORS++))
  else
    echo -e "  ${GREEN}PASS${NC}  [CHECK 1] Resource limits found"
  fi

  # ------------------------------------------------------------
  # CHECK 2 — No :latest image tag
  # ------------------------------------------------------------
  LATEST_LINES=$(grep "image:" "$FILE" | grep ":latest")

  if [ -n "$LATEST_LINES" ]; then
    echo -e "  ${RED}FAIL${NC}  [CHECK 2] Image using :latest tag"
    echo "        Found:"
    while IFS= read -r line; do
      echo "          $line"
    done <<< "$LATEST_LINES"
    echo "        Pin to a specific version e.g. nginx:1.27.3"
    ((ERRORS++))
    ((FILE_ERRORS++))
  else
    echo -e "  ${GREEN}PASS${NC}  [CHECK 2] No :latest tag found"
  fi

  # ------------------------------------------------------------
  # CHECK 3 — Liveness probe
  # ------------------------------------------------------------
  HAS_LIVENESS=$(grep -c "livenessProbe:" "$FILE")

  if [ "$HAS_LIVENESS" -eq 0 ]; then
    echo -e "  ${RED}FAIL${NC}  [CHECK 3] Missing livenessProbe"
    echo "        Add a livenessProbe so Kubernetes restarts"
    echo "        unhealthy containers automatically."
    ((ERRORS++))
    ((FILE_ERRORS++))
  else
    echo -e "  ${GREEN}PASS${NC}  [CHECK 3] livenessProbe found"
  fi

  # ------------------------------------------------------------
  # CHECK 4 — Readiness probe
  # ------------------------------------------------------------
  HAS_READINESS=$(grep -c "readinessProbe:" "$FILE")

  if [ "$HAS_READINESS" -eq 0 ]; then
    echo -e "  ${RED}FAIL${NC}  [CHECK 4] Missing readinessProbe"
    echo "        Add a readinessProbe so Kubernetes only sends"
    echo "        traffic to containers that are ready."
    ((ERRORS++))
    ((FILE_ERRORS++))
  else
    echo -e "  ${GREEN}PASS${NC}  [CHECK 4] readinessProbe found"
  fi

  # Per-file summary
  if [ "$FILE_ERRORS" -eq 0 ]; then
    echo -e "  ${GREEN}Result: all checks passed${NC}"
  else
    echo -e "  ${RED}Result: $FILE_ERRORS check(s) failed${NC}"
  fi

done

# =============================================================================
# Final summary
# =============================================================================
echo ""
echo "=============================================="
if [ "$ERRORS" -eq 0 ]; then
  echo -e " ${GREEN}ALL CHECKS PASSED — deployment allowed${NC}"
  echo "=============================================="
  exit 0
else
  echo -e " ${RED}VALIDATION FAILED — $ERRORS error(s) found${NC}"
  echo " Deployment is BLOCKED until all errors are fixed."
  echo "=============================================="
  exit 1
fi
