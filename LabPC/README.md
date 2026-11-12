# LabPC: copy this whole folder to the lab PC

Everything needed to measure System D in the project lab, with **two GUIs**. Each folder is
complete on its own (kit, model curves, MiniDSP filter files, the Lab D/E course routines) and
runs on the lab PCs' **MATLAB R2019b**.

| Folder | GUI | Source | Commit |
|---|---|---|---|
| `Labs_Ours/` | the main lab GUI | branch `main` | `Labs_Ours/VERSION.txt` |
| `Labs_Fable/` | the alternative GUI (built by Fable 5.2) | branch `gui-alt` | `Labs_Fable/VERSION.txt` |

## 1. Get it onto the lab PC
1. On your own PC: `git pull` in the labs repo.
2. Copy the folder **`LabPC/`** to the USB stick, then from the stick to the lab PC (for example
   `D:\LabPC\`). Work on the lab PC's copy, not on the stick.

## 2. Start a GUI
1. Plug the **UMIK in before starting MATLAB** (MATLAB lists audio devices only at start-up).
2. In MATLAB:
   ```matlab
   clear classes
   cd 'D:\LabPC\Labs_Ours\Project\Final design\lab-day\kit'     % or Labs_Fable\...
   labgui            % real measurements
   labgui('demo')    % rehearsal without hardware (separate demo_data folder)
   ```
3. Each GUI shows what to set up before every step (switchboard, MiniDSP bypass/on, gains),
   measures, and shows the graph with an OK / CHECK / BAD verdict and what to do next.

Without a GUI, the same steps run from the Command Window in either folder: `lab P`, `lab S`,
`lab F`, ... (`lab list` shows them all), or open `kit/lab_run.m` and use *Run Section*.

## 3. Settings for today (both GUIs)
- MiniDSP: filters pasted from `Project/Final design/data/dsp/MiniDSP_woofer_out1.txt` (Out 1) and
  `MiniDSP_midtw_out2.txt` (Out 2). **Out 1 = -5.8 dB**, Out 2 = 0 dB, no invert, no delay.
- Units are selected on the **switchboard** (woofer / mid / tweeter ON/OFF).
- Chamber: **vents plugged**. Zi station: one vent open at 160 mm.
- Board: try **Rp 3.3 -> 8.2 ohm** (keep Rs 4.7). See `Labs_Ours/Project/Final design/lab-day/TUNING.md`.
- Order: P (placement, MiniDSP bypassed) -> S -> S4 -> S5 -> F -> A -> S again; Zi: Z1-Z4, N1, N2.

## 4. Before leaving the lab
Copy the day's data back to the stick:
`<folder>\Project\Final design\lab-day\data\<date>\` (all measurements + `figures\` + the log).
Delete your files from the lab PC.

Back home, put that `data\<date>\` folder into the repo at
`Project/Final design/lab-day/data/<date>/` (on `main`), commit and push. Data from the Fable
GUI goes to the same place; its run files open in either GUI.

## 5. If something goes wrong
| Symptom | Fix |
|---|---|
| `Unrecognized property ... for class ...` at start | an old copy: use this folder (R2019b-safe since `f7ddcb5` / `546ef84`); run `clear classes` |
| "beeps.wav not found" | the GUI runs the routine from its own folder; else copy `Lab E/matlab/course/Beeps.wav` next to `labgui.m` |
| "no UMIK" / UMIK missing in the device list | plug it in, **restart MATLAB** |
| Zi station refuses to measure | type the series resistor (multimeter, about 32.9 ohm) in Settings |
| A real measurement must be stopped | Ctrl+C in the Command Window (Cancel only works in demo) |
| Anything else | photo of the Command Window; the commands (`lab S` ...) are the fallback |

## Rebuilding this folder (maintainers)
`bash LabPC/make_labpc.sh` copies the committed code of `main` and `gui-alt` into `Labs_Ours/` and
`Labs_Fable/` (without raw data, demo data and screenshots). Run it after changing either GUI,
test from the copies, and commit `LabPC/`.
