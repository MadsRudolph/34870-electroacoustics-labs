# The 10-Nov Run Section scripts (still work; the kit in `../kit/` is easier)

**Open / run:** `project_run.m` (anechoic chamber) and `zinf_run.m` (Zi/Nfield): one section per run, Ctrl+Enter.
**Edit:** `project_dims.m` (what is noted by hand on the day; stored in every data file).
**Don't touch:** `core/` (measure_*, compare_*, plot_project, zinf_calc: only called) and `tests/` (must print PASS).
Run section 0 first: it goes to this folder and makes `core/` findable. Data: `../data/project_*.mat`, `zinf_*.mat`.
To see these runs with lamps and verdicts: `labgui`, button "Load manual runs ...".
