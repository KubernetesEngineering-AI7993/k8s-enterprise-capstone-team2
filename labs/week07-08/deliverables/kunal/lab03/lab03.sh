set -euo pipefail

echo "=== Lab 03 – CI Pipeline ==="

echo ""
echo "--- Local YAML validation (simulating CI validate step) ---"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
count=0
fail=0
for f in $(find "$SCRIPT_DIR" "$ROOT/lab01" "$ROOT/lab02" "$ROOT/lab04" \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  # Helm templates contain `{{ ... }}` which is not valid YAML for a plain parser.
  # CI would typically validate rendered output (or use helm template + kubeconform).
  if [[ "$f" == *"/templates/"* ]]; then
    echo "  SKIP (Helm template): $f"
    continue
  fi
  count=$((count + 1))
  if python3 -c "import yaml; yaml.safe_load(open('$f'))" 2>/dev/null; then
    echo "  OK $f"
  else
    echo "  FAIL $f"
    fail=$((fail + 1))
  fi
done
echo "Validated $count file(s); $fail failure(s)."
[ "$fail" -eq 0 ] || exit 1

echo ""
echo "--- Pipeline definition ---"
echo "See ci-pipeline.yaml (GitHub Actions). Trigger: on PR merge only (pull_request types: [closed], if merged == true)."
echo "Stages: Checkout → Validate YAML → Build (mock) → Deploy (helm template)."
echo ""
echo "--- Done (full pipeline runs in GitHub on PR merge) ---"
