# analysis/: after the lab day (not needed at the lab PC)

- **Run these:** `results_labday` (figures + numbers of the 10-Nov write-up → `../results_2026-11-10/`), `pad_predict` (what other L-pads would do, from run R2), `import_labday` (raw lab-PC files → clean `../data/*.mat`), `labday_to_kit` (10-Nov runs → `../data/2026-11-10/` for the GUI/dashboard).
- **Edit these:** only to analyse a new day (copy one and change the file names).
- **Don't touch:** the helpers they call live in `../kit/core/` and `../manual/core/` (each script adds them to the path itself).
