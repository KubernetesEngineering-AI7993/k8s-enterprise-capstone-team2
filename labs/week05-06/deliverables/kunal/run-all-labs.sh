set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

run_lab() {
  local lab_dir="$1"
  local script_name="$2"
  local out_file="$3"
  echo "=== Running $lab_dir/$script_name -> $out_file ==="
  (cd "$SCRIPT_DIR/$lab_dir" && bash "./$script_name") | tee "$SCRIPT_DIR/$out_file"
}

run_cleanup() {
  if [[ -x "$SCRIPT_DIR/cleanup.sh" ]]; then
    echo "=== Running cleanup ==="
    bash "$SCRIPT_DIR/cleanup.sh"
  fi
}

# Clean once before starting
run_cleanup

run_lab lab01 lab01.sh lab01.txt
run_cleanup

run_lab lab02 lab02.sh lab02.txt
run_cleanup

run_lab lab03 lab03.sh lab03.txt
run_cleanup

run_lab lab04 lab04.sh lab04.txt
run_cleanup
