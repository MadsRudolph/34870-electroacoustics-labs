%% Zi/Nfield station (Lab D setup): the built system, Tue 10-Nov 15-17
% Open in the MATLAB editor on the lab PC and use "Run Section" (Ctrl+Enter)
% one section at a time. Every run is saved to ../data/zinf_<tag>.mat at once
% (a repeated tag gets _2, _3) and compared with the model / Lab D straight away.
%
% This is NOT the MiniDSP chain: the NI card drives the amplifier directly,
% through the series resistor, as in Lab D. Impedance: the series resistor in.
% Near field: resistor SHORTED, mic into the Nexus BEFORE switching it on.
% After every run: no rail warning, and no peak above 10 V.
%
% The first line of every section only makes MATLAB find the helper files in core/
% (also right after a MATLAB restart): leave it in.
% Newer, with a graph + verdict after every step: ../kit/labgui.m (buttons) or ../kit/lab_run.m.

%% 0. Settings: SET THESE FIRST
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
addpath('core', 'tests', fullfile('..', 'kit', 'core'));   % the helper files (core/ = called automatically)
R = NaN;            % series resistor, MULTIMETER value (Lab D: 32.9 ohm). Not R_E!
edit project_dims   % fill in the Zi/Nfield part (vent dims, coil DCR, panel no.)
test_zinf           % no hardware: must print PASS
return

%% Z1. Board input = what amplifier channel 2 sees (mid + tweeter through the board)
% Amp -> series R -> board input; both drivers connected. Model: |Z| min 4.4 ohm
% at ~5.9 kHz, about 6.4 ohm at 50 Hz. The low end must sit near the multimeter
% DC value of the board input (mid R_E 4.6 + coil DCR): that checks R and k.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_zinf('board', 'board', 'R', R, 'note', 'mid + tweeter on the board');

%% Z2. Board, midrange branch only (TWEETER OFF on the switchboard, or lift its lead if the board is wired straight)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_zinf('board_mid', 'board', 'R', R, 'note', 'tweeter off');

%% Z3. Board, tweeter branch only (MIDRANGE OFF on the switchboard, or lift its lead if the board is wired straight)
% Above ~20 kHz the 4.7 / 3.3 ohm pad dominates; below 1 kHz it is C_tw + L_tw.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_zinf('board_tw', 'board', 'R', R, 'note', 'midrange off');

%% Z4. Woofer in the box, final tuning: ONE vent open at 160 mm, other plugged, filling in
% Checks the box is as designed (Lab D: fb 23.4 Hz; model 24.6 Hz).
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_zinf('woofer_L160', 'woofer', 'R', R, 'note', 'one vent L = 160 mm, filling in');

%% NF1. Near field, cone, same tuning (resistor shorted, mic ~1 cm from the dust cap)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
Nav = 4; NexusVperPa = 1;
m = measure_zinf('nf_cone_L160', 'nearfield', 'Nav', Nav, 'NexusVperPa', NexusVperPa, ...
    'note', 'cone, one vent L = 160 mm');

%% NF2. Near field, vent mouth, same tuning
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_zinf('nf_vent_L160', 'nearfield', 'Nav', Nav, 'NexusVperPa', NexusVperPa, ...
    'note', 'vent mouth, L = 160 mm');

%% X. If time is left: BOTH vents open (never measured, the quiz model only estimated it)
% Measure the second vent's inner diameter and length first (project_dims).
% m = measure_zinf('woofer_2vents', 'woofer', 'R', R, 'note', 'both vents open, L = ? / ? mm');
% m = measure_zinf('nf_cone_2vents', 'nearfield', 'note', 'cone, both vents open');

%% Before you leave
% Copy ../data/ to the USB stick, delete our files from the lab PC, put the
% plugs back the way the box is meant to be stored.
