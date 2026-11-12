%% Zi/Nfield station (Lab D setup): the built system, Tue 10-Nov 15-17
% Open in the MATLAB editor on the lab PC and use "Run Section" (Ctrl+Enter)
% one section at a time. Every run is saved to ../data/zinf_<tag>.mat at once
% (a repeated tag gets _2, _3) and compared with the model / Lab D straight away.
%
% This is NOT the MiniDSP chain: the NI card drives the amplifier directly,
% through the series resistor, as in Lab D. Impedance: the series resistor in.
% Near field: resistor SHORTED, mic into the Nexus BEFORE switching it on.
% After every run: no rail warning, and no peak above 10 V.
% The functions these sections call live in core/ (no need to open them); the line
% "addpath core ../kit/core" at the top of each section makes them findable.
% Easier, with lamps and instructions in one window: ../kit/labgui.m (type: labgui).

%% 0. Settings: SET THESE FIRST
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
addpath core tests ../kit/core
R = NaN;            % series resistor, MULTIMETER value (Lab D: 32.9 ohm). Not R_E!
edit project_dims   % fill in the Zi/Nfield part (vent dims, coil DCR, panel no.)
test_zinf           % no hardware: must print PASS (tests/test_zinf.m)
return

%% Z1. Board input = what amplifier channel 2 sees (mid + tweeter through the board)
% Amp -> series R -> board input; both drivers connected. Model: |Z| min 4.4 ohm
% at ~5.9 kHz, about 6.4 ohm at 50 Hz. The low end must sit near the multimeter
% DC value of the board input (mid R_E 4.6 + coil DCR): that checks R and k.
addpath core ../kit/core
m = measure_zinf('board', 'board', 'R', R, 'note', 'mid + tweeter on the board');

%% Z2. Board, midrange branch only (tweeter lead off at the board)
addpath core ../kit/core
m = measure_zinf('board_mid', 'board', 'R', R, 'note', 'tweeter lead off');

%% Z3. Board, tweeter branch only (midrange lead off at the board)
% Above ~20 kHz the 4.7 / 3.3 ohm pad dominates; below 1 kHz it is C_tw + L_tw.
addpath core ../kit/core
m = measure_zinf('board_tw', 'board', 'R', R, 'note', 'midrange lead off');

%% Z4. Woofer in the box, final tuning: ONE vent open at 160 mm, other plugged, filling in
% Checks the box is as designed (Lab D: fb 23.4 Hz; model 24.6 Hz).
addpath core ../kit/core
m = measure_zinf('woofer_L160', 'woofer', 'R', R, 'note', 'one vent L = 160 mm, filling in');

%% NF1. Near field, cone, same tuning (resistor shorted, mic ~1 cm from the dust cap)
addpath core ../kit/core
Nav = 4; NexusVperPa = 1;
m = measure_zinf('nf_cone_L160', 'nearfield', 'Nav', Nav, 'NexusVperPa', NexusVperPa, ...
    'note', 'cone, one vent L = 160 mm');

%% NF2. Near field, vent mouth, same tuning
addpath core ../kit/core
m = measure_zinf('nf_vent_L160', 'nearfield', 'Nav', Nav, 'NexusVperPa', NexusVperPa, ...
    'note', 'vent mouth, L = 160 mm');

%% X. If time is left: BOTH vents open (never measured, the quiz model only estimated it)
% Measure the second vent's inner diameter and length first (project_dims).
% m = measure_zinf('woofer_2vents', 'woofer', 'R', R, 'note', 'both vents open, L = ? / ? mm');
% m = measure_zinf('nf_cone_2vents', 'nearfield', 'note', 'cone, both vents open');

%% Before you leave
% Copy ../data/ to the USB stick, delete our files from the lab PC, put the
% plugs back the way the box is meant to be stored.
