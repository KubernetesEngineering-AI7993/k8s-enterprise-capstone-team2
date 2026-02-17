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
  echo "=== Running cleanup ==="
  bash "$SCRIPT_DIR/cleanup.sh"
}

# Clean once before starting
run_cleanup

run_lab lab01 lab1.sh lab1.txt
run_cleanup

run_lab lab02 lab2.sh lab2.txt
run_cleanup

run_lab lab03 lab3.sh lab3.txt
run_cleanup

run_lab lab04 lab4.sh lab4.txt
run_cleanup