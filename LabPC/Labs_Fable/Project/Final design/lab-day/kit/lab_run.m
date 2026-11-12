%% LAB_RUN  The lab day as "Run Section" steps (the same as the GUI and as typing  lab P ...)
% Open this file in the MATLAB editor on the lab PC. Click inside a section and press
% "Run Section" (Ctrl+Enter). A box says what to set up; press Measure. Afterwards the
% dashboard opens on "Latest": measured vs expected, the difference, and a verdict
% (green OK / orange CHECK / red BAD). Data: ../data/<date>/<step>.mat, never overwritten.
%
% Easier: type  labgui  (the same steps with lamps, instructions and plots in one window).
% Plug the UMIK into USB BEFORE starting MATLAB. Do not touch the amplifier volume or
% move the microphone between runs. A run of 3 steps: switch during the ~30 s of beeps.
% The units are selected on the SWITCHBOARD in the chamber (Woofer / Mid / Tweeter ON or OFF,
% as in Lab E): no cable is pulled, nothing is muted in the MiniDSP, no lead is lifted.

%% 0. Before the first run: go to this folder, check the settings, test without hardware
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
edit lab_setup                          % Out 1 gain, amplifier, vent, series R, UMIK: edit, save
run(fullfile('tests', 'test_lab.m'))    % no hardware: must print PASS
return

%% -------- ANECHOIC CHAMBER (UMIK + sound card) --------

%% P. Placement check: P1 + P2 + P3 in one run (~4 min). MiniDSP BYPASSED.
% NOW: switchboard Woofer ON, Mid OFF, Tweeter OFF.
% Beeps 1: Woofer OFF, Mid ON (midrange only).
% Beeps 2: Mid OFF, Tweeter ON (tweeter only).
% All three must be OK (= same placement as Lab E). If not: move the box/mic, redo P.
lab P

%% P1. Placement: woofer only (~1 min). MiniDSP BYPASSED. Switchboard: Woofer ON, Mid OFF, Tweeter OFF.
lab P1

%% P2. Placement: midrange via the board. MiniDSP BYPASSED. Switchboard: Woofer OFF, Mid ON, Tweeter OFF.
lab P2

%% P3. Placement: tweeter via the board. MiniDSP BYPASSED. Switchboard: Woofer OFF, Mid OFF, Tweeter ON.
lab P3

%% P2d. Optional, only if the board can be bypassed: midrange wired STRAIGHT to the amplifier. MiniDSP BYPASSED. Switchboard: Mid ON only.
lab P2d

%% P3d. Optional, only if the board can be bypassed: tweeter wired STRAIGHT to the amplifier. MiniDSP BYPASSED. Switchboard: Tweeter ON only.
lab P3d

%% S. The system: S1 + S2 + S3 in one run (~4 min). MiniDSP ON (filters pasted, Out 1 gain as in lab_setup).
% NOW: switchboard Woofer ON, Mid OFF, Tweeter OFF.
% Beeps 1: Woofer OFF, Mid ON, Tweeter ON.
% Beeps 2: Woofer ON (all three, normal polarity).
% Verdict "bal" says how much to change the Out 1 gain; "sum" must be OK (nothing moved).
lab S

%% S1. System: woofer only. MiniDSP ON. Switchboard: Woofer ON, Mid OFF, Tweeter OFF.
lab S1

%% S2. System: mid + tweeter. MiniDSP ON. Switchboard: Woofer OFF, Mid ON, Tweeter ON.
lab S2

%% S3. System: all three. MiniDSP ON, normal polarity. Switchboard: all ON.
lab S3

%% S4. System: midrange only. MiniDSP ON. Switchboard: Woofer OFF, Mid ON, Tweeter OFF.
lab S4

%% S5. System: tweeter only. MiniDSP ON. Switchboard: Woofer OFF, Mid OFF, Tweeter ON.
lab S5

%% S4+S5+S3. Midrange / tweeter / all in ONE run (shared phase, as R2 on 10-Nov) (~4 min).
% NOW: switchboard Mid ON only. Beeps 1: Mid OFF, Tweeter ON.
% Beeps 2: Woofer ON, Mid ON (all three).
lab({'S4', 'S5', 'S3'})

%% F. Polarity flips: F0 + F1 + F2 in one run (~4 min). MiniDSP ON.
% Switchboard: all three ON the whole run.
% NOW: normal polarity (Out 1 invert not ticked).
% Beeps 1: tick Out 1 INVERT in the MiniDSP app.
% Beeps 2: UNtick it, swap the tweeter + and - at the board.
% AFTERWARDS: swap the tweeter back! Deep notches (329 Hz, 3.9 kHz) = in phase at the crossovers.
lab F

%% F0. Flip reference: all three ON, normal polarity.
lab F0

%% F1. Woofer inverted: Out 1 INVERT ticked. (Alone it has no reference: prefer the run F.)
lab F1

%% F2. Tweeter swapped: tweeter + and - swapped at the board. (Prefer the run F.) Swap back afterwards!
lab F2

%% A. 30 degrees: A1 + A2 + A3 in one run (~4 min). Turn the system 30 deg (as Lab E). MiniDSP ON.
% NOW: switchboard Woofer ON only. Beeps 1: Woofer OFF, Mid ON, Tweeter ON. Beeps 2: Woofer ON.
lab A

%% A1. 30 deg: woofer only. Switchboard: Woofer ON, Mid OFF, Tweeter OFF.
lab A1

%% A2. 30 deg: mid + tweeter. Switchboard: Woofer OFF, Mid ON, Tweeter ON.
lab A2

%% A3. 30 deg: all three. Switchboard: all ON.
lab A3

%% S again. Back at 0 deg: repeat S at the end (drift check: "all" must lie on the first one).
lab('S', 'note', 'repeat at the end')

%% -------- Zi/Nfield STATION (NI card, Lab D setup) --------
% Set R_series in lab_setup.m (multimeter value, about 32.9 ohm) before Z1-Z4.

%% Z1. Impedance, board input: amp -> series R -> board input, both drivers connected.
lab Z1

%% Z2. Impedance, board, mid branch: TWEETER switched OFF on the switchboard (or its lead lifted).
lab Z2

%% Z3. Impedance, board, tweeter branch: MIDRANGE switched OFF (or its lead lifted), tweeter back ON.
lab Z3

%% Z4. Impedance, woofer in the box: series R -> woofer. One vent open (lab_setup: vent_mm), the other plugged.
lab Z4

%% N1. Near field, cone: series R SHORTED. Mic ~1 cm from the dust cap. Nexus on, 1 V/Pa.
lab N1

%% N2. Near field, vent: series R SHORTED. Mic at the vent mouth.
lab N2

%% -------- ANY TIME --------

%% Everything measured today: the dashboard and the step list
lab

%% Before you leave
% Save the MiniDSP configuration to a file, photograph the board, copy ../data/<date>/
% to the USB stick, delete our files from the lab PC.
