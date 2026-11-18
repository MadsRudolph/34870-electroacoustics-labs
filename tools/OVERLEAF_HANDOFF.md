# Handoff: move Overleaf to a small repo (started 18 Nov 2026 on the laptop)

**Why:** the full labs repo (~1,234 files, ~305 MB) is too big for Overleaf. Overleaf kept only part
of it, and a push from Overleaf (93d5a6e, "tezt") deleted 112 files on main; restored in 23a3cf7.
**Until this is finished: do not push from the old Overleaf project.** Pulling into it is harmless.

**Plan (option 2):** Overleaf links to a separate small repo, `34870-labs-overleaf`, holding only the
report sources and figures (~154 files, ~32 MB). `tools/overleaf_sync.py` copies them across
(`export`) and brings Overleaf edits back (`import`). Tested 18 Nov: every report compiles from the
small copy (Lab D and Lab E reports compile from the project root, as Overleaf does; they already
did not compile from their own folder in the full repo).

## Done
- `tools/overleaf_sync.py` committed and pushed (a4cd7d0).
- The listening-test analysis is on main (9af06ec): `Project/Final design/listening-test/results_2026-11-18/`.

## To do, on any PC
1. GitHub: create **`MadsRudolph/34870-labs-overleaf`**, private, empty (no README) at github.com/new.
2. Build the small repo (the laptop's local copy is not needed, it is regenerated):
   ```
   cd "~/DTU/5. Semester/Electroacoustics/Labs" && git pull
   mkdir -p ~/overleaf/34870-labs-overleaf && cd ~/overleaf/34870-labs-overleaf && git init -b main
   cd "~/DTU/5. Semester/Electroacoustics/Labs" && python3 tools/overleaf_sync.py export
   cd ~/overleaf/34870-labs-overleaf
   ```
   Add `OVERLEAF.md` (short README: the repo is generated, edit in Overleaf, round trip below) and a
   `.gitignore` for LaTeX build files (`*.aux *.log *.out *.toc *.synctex.gz *.fls *.fdb_latexmk *.bbl *.blg`), then
   ```
   git add -A && git commit -m "Report sources and figures from the labs repo"
   git remote add origin git@github.com:MadsRudolph/34870-labs-overleaf.git && git push -u origin main
   ```
3. Overleaf, **old project:** Menu → GitHub → **Unlink** (keeps the project, stops the bad pushes).
4. Overleaf, **new project:** New Project → Import from GitHub → `34870-labs-overleaf`. Share it with
   the group; add them on GitHub too if they should push.
5. Tell the group: edit reports in the new Overleaf project; data and scripts stay in the labs repo.

## Round trip afterwards (in the labs repo)
1. `git -C ~/overleaf/34870-labs-overleaf pull` (Overleaf edits)
2. `python3 tools/overleaf_sync.py import` → `git diff` → commit here
3. `python3 tools/overleaf_sync.py export` → commit + push the small repo → Overleaf: Menu → GitHub → Pull

`import` never deletes in the labs repo; it only lists files deleted in Overleaf.
