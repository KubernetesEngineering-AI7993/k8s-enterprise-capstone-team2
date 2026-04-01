#!/usr/bin/env bash
# =============================================================================
# validate.sh – Kubernetes Manifest Validator
# Week 09-10 | Kunal
# =============================================================================
# Usage:
#   bash validate.sh <manifest.yaml>          # validate a single file
#   bash validate.sh manifests/               # validate all yaml in a directory
#
# Exit codes:
#   0 – all checks passed
#   1 – one or more checks failed
#
# Checks performed on every Deployment found in the manifest:
#   1. Resource limits (cpu + memory) set on all containers
#   2. No container uses 'latest' image tag
#   3. Liveness probe defined on all containers
#   4. Readiness probe defined on all containers
# =============================================================================

# ---- colors ------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

pass()  { echo -e "  ${GREEN}[PASS]${RESET} $*"; }
fail()  { echo -e "  ${RED}[FAIL]${RESET} $*"; FAILED=$((FAILED + 1)); }
warn()  { echo -e "  ${YELLOW}[WARN]${RESET} $*"; }
info()  { echo -e "${CYAN}-->${RESET} $*"; }
section() { echo -e "\n${BOLD}$*${RESET}"; }

# ---- dependency check --------------------------------------------------------
for dep in python3; do
  command -v "$dep" &>/dev/null || { echo "ERROR: $dep is required"; exit 1; }
done

# ---- argument handling -------------------------------------------------------
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: bash validate.sh <manifest.yaml|directory>"
  exit 1
fi

# Collect yaml files
FILES=()
if [[ -d "$TARGET" ]]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(find "$TARGET" -name "*.yaml" -o -name "*.yml")
else
  FILES=("$TARGET")
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No YAML files found in: $TARGET"
  exit 1
fi

# ---- global counters ---------------------------------------------------------
TOTAL_DEPLOYMENTS=0
TOTAL_FAILED=0
TOTAL_PASSED=0

# =============================================================================
# validate_deployment – runs all 4 checks against one Deployment document
# Arguments:
#   $1 = file path
#   $2 = deployment name
#   $3 = raw YAML of the deployment (passed via temp file)
# =============================================================================
validate_deployment() {
  local FILE="$1"
  local NAME="$2"
  local TMPFILE="$3"
  FAILED=0

  section "Deployment: ${NAME}  (${FILE})"

  # Extract container list as JSON for easier parsing
  CONTAINERS=$(python3 - "$TMPFILE" <<'PYEOF'
import sys, yaml, json
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
containers = doc.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
print(json.dumps(containers))
PYEOF
)

  if [[ -z "$CONTAINERS" || "$CONTAINERS" == "null" || "$CONTAINERS" == "[]" ]]; then
    warn "No containers found — skipping"
    return
  fi

  CONTAINER_NAMES=$(python3 -c "import sys,json; cs=json.loads(sys.argv[1]); print('\n'.join(c['name'] for c in cs))" "$CONTAINERS")

  while IFS= read -r CNAME; do
    [[ -z "$CNAME" ]] && continue
    info "Container: ${CNAME}"

    # ------------------------------------------------------------------
    # CHECK 1: Resource limits (cpu and memory must both be set)
    # ------------------------------------------------------------------
    CPU_LIMIT=$(python3 -c "
import sys, json
cs = json.loads(sys.argv[1])
c = next((x for x in cs if x['name'] == sys.argv[2]), {})
print(c.get('resources', {}).get('limits', {}).get('cpu', ''))
" "$CONTAINERS" "$CNAME")

    MEM_LIMIT=$(python3 -c "
import sys, json
cs = json.loads(sys.argv[1])
c = next((x for x in cs if x['name'] == sys.argv[2]), {})
print(c.get('resources', {}).get('limits', {}).get('memory', ''))
" "$CONTAINERS" "$CNAME")

    if [[ -n "$CPU_LIMIT" && -n "$MEM_LIMIT" ]]; then
      pass "Resource limits set (cpu: ${CPU_LIMIT}, memory: ${MEM_LIMIT})"
    elif [[ -z "$CPU_LIMIT" && -z "$MEM_LIMIT" ]]; then
      fail "Resource limits missing — no cpu or memory limits defined"
    elif [[ -z "$CPU_LIMIT" ]]; then
      fail "Resource limits incomplete — cpu limit missing (memory: ${MEM_LIMIT})"
    else
      fail "Resource limits incomplete — memory limit missing (cpu: ${CPU_LIMIT})"
    fi

    # ------------------------------------------------------------------
    # CHECK 2: No 'latest' image tag
    # ------------------------------------------------------------------
    IMAGE=$(python3 -c "
import sys, json
cs = json.loads(sys.argv[1])
c = next((x for x in cs if x['name'] == sys.argv[2]), {})
print(c.get('image', ''))
" "$CONTAINERS" "$CNAME")

    if [[ "$IMAGE" == *":latest" || "$IMAGE" == *"@"* ]]; then
      # digest pinning (@sha256:...) is acceptable
      if [[ "$IMAGE" == *"@sha256:"* ]]; then
        pass "Image pinned by digest: ${IMAGE}"
      else
        fail "Image uses ':latest' tag — pin to a specific version (found: ${IMAGE})"
      fi
    elif [[ "$IMAGE" != *":"* ]]; then
      fail "Image has no tag — implicit 'latest' (found: ${IMAGE})"
    else
      pass "Image tag is pinned: ${IMAGE}"
    fi

    # ------------------------------------------------------------------
    # CHECK 3: Liveness probe defined
    # ------------------------------------------------------------------
    LIVENESS=$(python3 -c "
import sys, json
cs = json.loads(sys.argv[1])
c = next((x for x in cs if x['name'] == sys.argv[2]), {})
print('yes' if c.get('livenessProbe') else 'no')
" "$CONTAINERS" "$CNAME")

    if [[ "$LIVENESS" == "yes" ]]; then
      pass "Liveness probe defined"
    else
      fail "Liveness probe missing — kubelet cannot detect deadlocked containers"
    fi

    # ------------------------------------------------------------------
    # CHECK 4: Readiness probe defined
    # ------------------------------------------------------------------
    READINESS=$(python3 -c "
import sys, json
cs = json.loads(sys.argv[1])
c = next((x for x in cs if x['name'] == sys.argv[2]), {})
print('yes' if c.get('readinessProbe') else 'no')
" "$CONTAINERS" "$CNAME")

    if [[ "$READINESS" == "yes" ]]; then
      pass "Readiness probe defined"
    else
      fail "Readiness probe missing — Service will route traffic to unready pods"
    fi

    echo ""
  done <<< "$CONTAINER_NAMES"

  # Per-deployment result
  if [[ "$FAILED" -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}Result: PASSED${RESET} — all checks passed for ${NAME}"
    TOTAL_PASSED=$((TOTAL_PASSED + 1))
  else
    echo -e "  ${RED}${BOLD}Result: FAILED${RESET} — ${FAILED} check(s) failed for ${NAME}"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
  fi
  TOTAL_DEPLOYMENTS=$((TOTAL_DEPLOYMENTS + 1))
}

# =============================================================================
# Main – iterate over files, extract Deployments, validate each
# =============================================================================
echo -e "\n${BOLD}============================================================${RESET}"
echo -e "${BOLD} Kubernetes Manifest Validator${RESET}"
echo -e "${BOLD}============================================================${RESET}"
echo "Target: $TARGET"
echo "Files:  ${#FILES[@]}"

# Use a temp file to collect results — avoids subshell variable scope loss
RESULTS_FILE=$(mktemp)

for FILE in "${FILES[@]}"; do
  PAIRS=$(python3 - "$FILE" <<'PYEOF'
import sys, yaml, tempfile
with open(sys.argv[1]) as f:
    docs = list(yaml.safe_load_all(f))
for doc in docs:
    if doc and doc.get('kind') == 'Deployment':
        tmp = tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False)
        yaml.dump(doc, tmp)
        tmp.close()
        print(f"{tmp.name}|{doc.get('metadata',{}).get('name','unknown')}")
PYEOF
)
  while IFS= read -r TMPPATH; do
    [[ -z "$TMPPATH" ]] && continue
    TMPFILE="${TMPPATH%%|*}"
    DEPNAME="${TMPPATH##*|}"
    validate_deployment "$FILE" "$DEPNAME" "$TMPFILE"

    if [[ "$FAILED" -eq 0 ]]; then
      echo "RESULT|PASSED" >> "$RESULTS_FILE"
    else
      echo "RESULT|FAILED" >> "$RESULTS_FILE"
    fi
    rm -f "$TMPFILE"
  done <<< "$PAIRS"
done

# Tally from results file (parent shell reads it — no subshell scope loss)
while IFS= read -r LINE; do
  case "$LINE" in
    "RESULT|PASSED") TOTAL_PASSED=$((TOTAL_PASSED + 1)); TOTAL_DEPLOYMENTS=$((TOTAL_DEPLOYMENTS + 1)) ;;
    "RESULT|FAILED") TOTAL_FAILED=$((TOTAL_FAILED + 1)); TOTAL_DEPLOYMENTS=$((TOTAL_DEPLOYMENTS + 1)) ;;
  esac
done < "$RESULTS_FILE"
rm -f "$RESULTS_FILE"

# =============================================================================
# Final summary
# =============================================================================
echo ""
echo -e "${BOLD}============================================================${RESET}"
echo -e "${BOLD} Summary${RESET}"
echo -e "${BOLD}============================================================${RESET}"
echo "  Deployments checked : ${TOTAL_DEPLOYMENTS}"
echo -e "  Passed              : ${GREEN}${TOTAL_PASSED}${RESET}"
echo -e "  Failed              : ${RED}${TOTAL_FAILED}${RESET}"
echo ""

if [[ "$TOTAL_FAILED" -gt 0 ]]; then
  echo -e "${RED}${BOLD}VALIDATION FAILED — fix the issues above before deploying.${RESET}"
  exit 1
else
  echo -e "${GREEN}${BOLD}VALIDATION PASSED — all deployments meet required standards.${RESET}"
  exit 0
fi
