# After the lab: scripts that turn a lab day into results

**Run:** `results_labday` (figures + numbers of the 10-Nov write-up -> `../results_2026-11-10/`), `pad_predict` (other L-pads on the measured data).
**Run once per lab day:** `import_labday` (lab-PC files in `../raw data/` -> small annotated files in `../data/`), `labday_to_kit` (-> kit format in `../data/2026-11-10/`).
**Edit:** the tables at the top of `import_labday.m` / `labday_to_kit.m` when a new day is imported.
Nothing here measures. Everything they call is in `../kit/core/` and found through `labpaths`.
Each script can be run from anywhere (it adds its own paths).
