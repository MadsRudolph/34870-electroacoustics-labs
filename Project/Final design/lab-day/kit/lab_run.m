%% Lab day, section by section (the editor way; the same as the GUI's buttons)
% Open this file in the MATLAB editor on the lab PC. Click inside a section and press
% "Run Section" (Ctrl+Enter). Each section measures one step or one run: a box shows
% what to set up, press Measure, and the graphs + verdict (OK / CHECK / BAD) appear.
% Data go to lab-day/data/<today>/ (repeats get _2, _3, never overwritten).
%
% The first line of each section only makes sure MATLAB is in this folder: leave it.
% Settings of the day: lab_setup.m, or the GUI's settings (labgui saves them in
% data/<today>/session.json, and these commands use that file too).
% Plug the UMIK into USB BEFORE starting MATLAB. In a run of 3 steps, switch only
% during the ~30 s of beeps.

%% 0. Before the first measurement (no hardware needed)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
edit lab_setup          % Out 1 gain (-10.3), amplifier, vent 160 mm, UMIK serial
addpath tests; test_lab % must print PASS (stand-in routines, no hardware)
lab list                % the step list
return

%% P. Placement check, MiniDSP BYPASSED: woofer / mid / tweeter in one run (~4 min)
% Start: amp ch. 2 cable pulled. Beeps 1: ch. 1 pulled, tweeter lead off. Beeps 2: mid lead off, tweeter on.
% All three should be OK before going on (else: box/mic position differs from Lab E).
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab P

%% S. The system, MiniDSP ON: woofer / mid+tw / all in one run (~4 min)
% Start: amp ch. 2 cable pulled. Beeps 1: ch. 2 back, ch. 1 pulled. Beeps 2: ch. 1 back.
% Checks: balance woofer vs mid+tw (+-1 dB; it says how to change Out 1) and the sum check.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab S

%% S4. Midrange only (MiniDSP on, amp ch. 1 pulled, TWEETER lead off) (~1 min)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab S4

%% S5. Tweeter only (MiniDSP on, amp ch. 1 pulled, MIDRANGE lead off) (~1 min)
% After S4 + S5 the verdict also prints the tweeter level against the midrange.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab S5

%% F. Polarity flips: all / woofer inverted / tweeter swapped (~4 min)
% Beeps 1: tick Out 1 INVERT. Beeps 2: untick it, swap the tweeter + and - at the board.
% AFTERWARDS: swap the tweeter back!
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab F

%% A. 30 degrees: woofer / mid+tw / all (~4 min)
% Turn the system 30 deg (as in Lab E). Same switching as S. Turn back afterwards.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab A

%% Z1. Zi station: board input impedance (series R in, both drivers connected) (~20 s)
% Type the MULTIMETER value of the series resistor in lab_setup.m (R_series) or the GUI first.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab Z1

%% Z2. Board, midrange branch (TWEETER lead off at the board)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab Z2

%% Z3. Board, tweeter branch (MIDRANGE lead off, tweeter lead back on)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab Z3

%% Z4. Woofer in the box: one vent open at vent_mm (160), the other plugged
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab Z4

%% N1. Near field, cone: series R SHORTED, mic ~1 cm from the dust cap, Nexus 1 V/Pa (~40 s)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab N1

%% N2. Near field, vent mouth
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab N2

%% Any time: the dashboard of everything measured today (all tabs, saved as PNG)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
lab

%% Before you leave: copy data/<today>/ to the USB stick
% Easiest: labgui -> "Copy day to USB...". By hand: copy the folder lab-day/data/<today>
% (and any lab-day/data/project_*.mat / zinf_*.mat made with the Tuesday scripts).
