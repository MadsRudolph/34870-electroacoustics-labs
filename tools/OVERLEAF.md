# Overleaf workflow (since 18 Nov 2026)

Read this before touching any report `.tex` or figure that Overleaf uses, whether you are a person or
a coding agent.

## The setup

| | Labs repo (this repo) | Overleaf repo |
|---|---|---|
| GitHub | `MadsRudolph/34870-electroacoustics-labs` | `MadsRudolph/34870-labs-overleaf` (private) |
| On disk | `~/DTU/5. Semester/Electroacoustics/Labs` | `~/overleaf/34870-labs-overleaf` |
| Holds | everything: data, scripts, figures, reports | only the report sources + the figures they use (~154 files, ~32 MB), at the **same paths** |
| Linked to Overleaf? | **no** | **yes**: [Overleaf project](https://www.overleaf.com/project/6afe0b5b02e06a98c0638cc2) |

The two repos are **separate**: not a submodule, not nested, no git link between them. The Overleaf
repo lives outside `~/DTU` on purpose (no nested repo, no Syncthing). The only connection is
`tools/overleaf_sync.py`, which copies files between the two folders:

- `export` copies labs repo → Overleaf repo (and removes files it exported earlier that are no longer needed; it tracks them in `.overleaf_manifest`, which is committed in the Overleaf repo)
- `import` copies Overleaf repo → labs repo (every file that differs; never deletes here, only lists files deleted in Overleaf)
- `list` shows what would be exported
- add `--dry-run` to `export`/`import` to see what would happen without writing anything

Neither command commits or pushes. The labs repo is the **source of truth**; the Overleaf repo is a
generated copy that Overleaf edits flow through.

**Why:** the full labs repo (~1,234 files, ~305 MB) is too big for Overleaf. The old Overleaf project,
linked straight to the labs repo, kept only part of it, and a push from it (93d5a6e, 18 Nov) deleted
112 files on main (restored in 23a3cf7). That old project (`6aaff1032e7b434d4389c28f`) is **archived. Never un-archive it and never
push from it.**

## Round 1: bring Overleaf edits in (do this FIRST, every time)

Do this before editing reports locally and before every export. `import` overwrites the labs-repo copy
of every file that differs, so if you edit locally first and import afterwards, your newer local edit
is replaced by the older Overleaf version.

1. Overleaf: **Menu → GitHub → Push Overleaf changes to GitHub** (only needed if anyone edited in Overleaf; ask the group if unsure).
2. In the labs repo, with a clean working tree (`git status`, commit or stash first):
   ```
   git pull
   git -C ~/overleaf/34870-labs-overleaf pull
   python3 tools/overleaf_sync.py import --dry-run   # look first
   python3 tools/overleaf_sync.py import
   git diff                                          # check it is really the Overleaf edits
   git add -A && git commit -m "Report edits from Overleaf" && git push
   ```
   If `import` reports 0 files, there is nothing to commit; go on.

## Round 2: send local edits to Overleaf

1. Edit, build (`tectonic "<path>/report/<Main>.tex"`), commit and push in the labs repo as usual.
2. Export and push the Overleaf repo:
   ```
   python3 tools/overleaf_sync.py export
   cd ~/overleaf/34870-labs-overleaf
   git status                     # should show only the files you changed
   git add -A && git commit -m "<what changed>" && git push
   ```
   If `git push` is rejected, someone pushed from Overleaf in the meantime: **do not force-push**.
   In the Overleaf repo run `git fetch && git reset --hard origin/main` (throws away only the generated
   export commit), go back to Round 1, then export again.
3. Overleaf: **Menu → GitHub → Pull GitHub changes into Overleaf**. Only a person can do this click.

## Rules for agents

- Edit reports **in the labs repo**, never directly in `~/overleaf/34870-labs-overleaf`; the next `export` overwrites edits made there.
- Always do Round 1 before Round 2. Never `git push --force` the Overleaf repo.
- Never add the Overleaf repo inside the labs repo or the `~/DTU` umbrella repo.
- A new figure or `\input` file reaches Overleaf only if `overleaf_sync.py` sees it: it must be **committed** in the labs repo and either sit next to a main `.tex` or be referenced from it. Check with `python3 tools/overleaf_sync.py list`. Nothing over 10 MB and nothing under `LabPC/` is exported.
- The Overleaf clicks (push to GitHub, pull from GitHub, main document, sharing) need Mads or a teammate in the browser. Say exactly which click is needed.
- Commit messages: plain, no AI attribution.

## On a new PC

```
git clone git@github.com:MadsRudolph/34870-labs-overleaf.git ~/overleaf/34870-labs-overleaf
```
Another folder works too: pass `--to DIR` or set `OVERLEAF_REPO`.

## Overleaf notes

- Each lab has its own main document: set **Menu → Main document** to the report you compile, e.g.
  `Lab A/report/LabA_report.tex` or `Project/Final design/report/Project_report.tex`.
- Overleaf has no per-project "unlink from GitHub". The account-level Unlink (Account Settings →
  Integrations) disconnects every project, so don't use it.
- Don't edit the same file in Overleaf and locally between two rounds; nothing merges it for you.
