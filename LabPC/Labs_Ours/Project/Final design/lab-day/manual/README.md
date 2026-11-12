# manual/: Tuesday's section scripts (the way of 10-Nov)

- **Open / run these:** `project_run.m` (anechoic chamber) and `zinf_run.m` (Zi / near field). Open in the editor, click in a section, *Run Section* (Ctrl+Enter). Section 0 first.
- **Edit this:** `project_dims.m` (what you note by hand: UMIK label, temperature, distances, board parts). Stored in every file.
- **Don't touch:** `core/` (called automatically) and `tests/` (`test_project`, `test_zinf`: no hardware, must print PASS).
- Data go to `lab-day/data/project_<tag>.mat` / `zinf_<tag>.mat`, figures to `lab-day/figures/`. The GUI shows these runs too: `labgui` → *Load manual runs...*.
- The newer way with a graph + verdict after every step is `../kit/` (`labgui`, or `lab_run.m` section by section).
