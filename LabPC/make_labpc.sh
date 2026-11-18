#!/usr/bin/env bash
# Rebuild LabPC/ from the committed code: ours from main (HEAD), Fable's from the gui-alt branch.
# Run from anywhere inside the labs repo:  bash LabPC/make_labpc.sh   then commit LabPC/.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git fetch -q origin gui-alt || true
ALT=$(git rev-parse --verify -q origin/gui-alt || git rev-parse --verify gui-alt)
PATHS=("Project/Final design/lab-day" "Project/Final design/data/dsp" "Project/Final design/data/csv"
       "Project/Final design/design/design.json" "Lab D/matlab" "Lab D/data" "Lab E/matlab")
EXCL=(":(exclude)Project/Final design/lab-day/raw data" ":(exclude)**/tests/screenshots/**"
      ":(exclude)**/screenshots/**" ":(exclude)Project/Final design/lab-day/demo_data")
for pair in "Labs_Ours:HEAD" "Labs_Fable:$ALT"; do
  dir=${pair%%:*}; rev=${pair#*:}
  rm -rf "LabPC/$dir"; mkdir -p "LabPC/$dir"
  git archive "$rev" -- "${PATHS[@]}" "${EXCL[@]}" | tar -x -C "LabPC/$dir"
  git rev-parse --short "$rev" > "LabPC/$dir/VERSION.txt"
done
du -sh LabPC/Labs_Ours LabPC/Labs_Fable
