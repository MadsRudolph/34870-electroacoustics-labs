#!/usr/bin/env python3
"""Keep the small Overleaf repo in step with this labs repo.

The full labs repo is too big for Overleaf: Overleaf keeps only part of it, and a push from
Overleaf then deletes everything it did not keep. So Overleaf is linked to a separate small repo
that holds only what the reports need (each main .tex, the files next to it and the figures it
uses), at the same paths as here, so every report compiles the same way in both places.

    python3 tools/overleaf_sync.py export   [--to DIR] [--dry-run]   labs repo -> Overleaf repo
    python3 tools/overleaf_sync.py import   [--to DIR] [--dry-run]   Overleaf repo -> labs repo
    python3 tools/overleaf_sync.py list                              what would be exported

export: copies the report files into the Overleaf repo (default ~/overleaf/34870-labs-overleaf, or
$OVERLEAF_REPO), removes files it exported earlier that are no longer needed, and leaves the commit
and push to you. import: copies back every file that differs from the labs repo (edits made in
Overleaf, new figures) and lists what it did; files deleted in Overleaf are only reported, never
deleted here. Neither command commits or pushes.

Typical round: git pull in the Overleaf repo (gets the Overleaf edits) -> import -> commit here;
then export -> commit + push the Overleaf repo -> "Pull GitHub changes into Overleaf".
"""
import argparse
import filecmp
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

LABS = Path(__file__).resolve().parents[1]
DEFAULT = Path(os.environ.get('OVERLEAF_REPO', Path.home() / 'overleaf' / '34870-labs-overleaf'))
MANIFEST = '.overleaf_manifest'
OWN = {MANIFEST, 'OVERLEAF.md', '.gitignore'}  # the Overleaf repo's own files, never imported
SKIP_PREFIXES = ('LabPC/',)                # copies of the lab-PC kit, not reports
SIDE_EXT = {'.tex', '.bib', '.sty', '.cls', '.bst', '.png', '.jpg', '.jpeg', '.pdf', '.eps', '.svg'}
IMG_EXT = ['', '.pdf', '.png', '.jpg', '.jpeg', '.eps']
MAX_BYTES = 10_000_000                     # nothing big goes to Overleaf


def tracked():
    out = subprocess.run(['git', '-C', str(LABS), 'ls-files', '-z'], capture_output=True, check=True).stdout
    return [p for p in out.decode().split('\0') if p]


def wanted():
    files = tracked()
    have = set(files)
    keep = {'README.md'} & have
    for f in files:
        if not f.endswith('.tex') or f.startswith(SKIP_PREFIXES):
            continue
        src = (LABS / f).read_text(errors='ignore')
        if '\\documentclass' not in src:
            continue
        d = Path(f).parent
        keep.add(f)
        # everything next to the main document (sources, generated inputs, its own figures and PDF)
        for g in files:
            gp = Path(g)
            if gp.parent == d and gp.suffix.lower() in SIDE_EXT:
                keep.add(g)
        # graphicspath entries are written twice: relative to the .tex and relative to the repo root
        paths = [Path('.')]
        for grp in re.findall(r'\\graphicspath\{(.*)\}', src):
            paths += [Path(p) for p in re.findall(r'\{([^{}]*)\}', grp)]
        bases = []
        for p in paths:
            for b in (d / p, p):
                b = Path(os.path.normpath(b))
                if b not in bases:
                    bases.append(b)
        # any {argument} that names a tracked file: \includegraphics, \input, and custom commands
        # such as \fig{...} or \verbfile{...}; a macro path like ../data/dsp/#1 adds its folder
        args = [a.strip().strip('"') for a in re.findall(r'\{([^{}\n]{1,200})\}', src)]
        for a in args:
            if '#1' in a:
                pre = a.split('#1')[0]
                for b in (d / pre, Path(pre)):
                    b = Path(os.path.normpath(b))
                    if b not in bases:
                        bases.append(b)
        for n in (a for a in args if '#' not in a and '\\' not in a):
            for b in bases:
                hit = next((str(Path(os.path.normpath(b / (n + e)))) for e in IMG_EXT + ['.tex']
                            if str(Path(os.path.normpath(b / (n + e)))) in have), None)
                if hit:
                    keep.add(hit)
                    break
        # \input via a macro (#1): take every .tex in the folders it may point to
        if '#1' in src:
            for g in files:
                if g.endswith('.tex') and Path(g).parent == d:
                    keep.add(g)
    big = sorted(k for k in keep if (LABS / k).stat().st_size > MAX_BYTES)
    for k in big:
        print(f'skipped (over {MAX_BYTES // 1_000_000} MB): {k}', file=sys.stderr)
    return sorted(keep - set(big))


def export(dest, dry):
    if not (dest / '.git').exists():
        sys.exit(f'{dest} is not a git repo. Clone the Overleaf repo there first (see the README).')
    keep = wanted()
    old = set((dest / MANIFEST).read_text().split('\n')) - {''} if (dest / MANIFEST).exists() else set()
    n_new = n_upd = 0
    for f in keep:
        s, t = LABS / f, dest / f
        if t.exists() and filecmp.cmp(s, t, shallow=False):
            continue
        n_new += not t.exists()
        n_upd += t.exists()
        print(('new     ' if not t.exists() else 'update  ') + f)
        if not dry:
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(s, t)
    gone = sorted(old - set(keep))
    for f in gone:
        if (dest / f).exists():
            print('remove  ' + f)
            if not dry:
                (dest / f).unlink()
    if not dry:
        (dest / MANIFEST).write_text('\n'.join(keep) + '\n')
    size = sum((LABS / f).stat().st_size for f in keep)
    print(f'{len(keep)} files, {size / 1e6:.1f} MB; {n_new} new, {n_upd} updated, {len(gone)} removed'
          + (' (dry run, nothing written)' if dry else ''))


def import_(dest, dry):
    if not (dest / '.git').exists():
        sys.exit(f'{dest} is not a git repo.')
    have = set(tracked())
    exported = set((dest / MANIFEST).read_text().split('\n')) - {''} if (dest / MANIFEST).exists() else set()
    out = subprocess.run(['git', '-C', str(dest), 'ls-files', '-z'], capture_output=True, check=True).stdout
    theirs = [p for p in out.decode().split('\0') if p and p not in OWN and not p.startswith('.git')]
    n = 0
    for f in theirs:
        s, t = dest / f, LABS / f
        if not s.exists() or (t.exists() and filecmp.cmp(s, t, shallow=False)):
            continue
        n += 1
        print(('changed in Overleaf  ' if t.exists() else 'new in Overleaf      ') + f)
        if not dry:
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(s, t)
    for f in sorted(exported - set(theirs)):
        if f in have:
            print('deleted in Overleaf (kept here, delete by hand if meant): ' + f)
    print(f'{n} file(s) brought back' + (' (dry run, nothing written)' if dry else '') +
          '. Check with git diff, then commit in the labs repo.')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('cmd', choices=['export', 'import', 'list'])
    ap.add_argument('--to', type=Path, default=DEFAULT, help=f'Overleaf repo (default {DEFAULT})')
    ap.add_argument('--dry-run', action='store_true')
    a = ap.parse_args()
    if a.cmd == 'list':
        keep = wanted()
        print('\n'.join(keep))
        print(f'{len(keep)} files, {sum((LABS / f).stat().st_size for f in keep) / 1e6:.1f} MB', file=sys.stderr)
    elif a.cmd == 'export':
        export(a.to.expanduser(), a.dry_run)
    else:
        import_(a.to.expanduser(), a.dry_run)


if __name__ == '__main__':
    main()
