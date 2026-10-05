%% Lab D: run the measurements from here
% Open this file in the MATLAB editor. Each measurement is its own section:
% edit the values in that section, click inside it and press
% "Run Section" (Ctrl+Enter). Every run is saved to ../data/labD_<tag>.mat
% straight away; a repeated tag gets _2, _3 ... so nothing is overwritten.
%
% Check after every run: the printed rms of AI1 (the driver) should be
% about 0.1 V for the impedance measurements, and no peak may exceed 10 V.

%% 0. Settings shared by every measurement: SET THESE FIRST
R = 33.0;          % series resistor measured with the multimeter (ohm)
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end   % run from this folder

%% 0b. Check the copy works (no hardware): must print PASS
test_labD

%% 2a1. Tweeter impedance (100 Hz - 24 kHz)
tag  = 'tweeter';
note = '';
m = measure_labD(tag, 'tweeter', 'R', R, 'note', note);

%% 2a2. Midrange impedance (20 Hz - 20 kHz)
tag  = 'midrange';
note = '';
m = measure_labD(tag, 'midrange', 'R', R, 'note', note);

%% 2b1. Woofer in free air (back cover off, filling out, facing open room)
tag  = 'woofer_free';
note = 'free air, cover off, no filling';
m = measure_labD(tag, 'woofer', 'R', R, 'note', note);

%% 2b2. Woofer in the closed box (cover on, both vents plugged, no filling)
tag  = 'woofer_closed';
note = 'closed box, vents plugged, no filling';
m = measure_labD(tag, 'woofer', 'R', R, 'note', note);

%% 2b4. Woofer with the vent open: change tag, length and note for each tube
tag  = 'vent_L1';            % vent_L1, vent_L2, vent_L3 ...
L_mm = 50;                   % tube length you measured (mm)
open_vents = 1;              % 1 or 2
note = sprintf('vented, %d open, L = %g mm', open_vents, L_mm);
m = measure_labD(tag, 'woofer', 'R', R, 'note', note);

%% 3. Near field (mic into the Nexus BEFORE switching it on, Nexus -> AI1, resistor shorted)
tag       = 'nf_cone_L1';    % nf_cone_L1 / nf_vent_L1, then L2, L3 ...
where     = 'cone';          % 'cone' or 'vent'
L_mm      = 50;              % vent tube length during this measurement (mm)
Nav       = 4;               % raise to 8 or 16 if the low end is noisy
NexusVperPa = 1;             % Nexus output setting: 1 V/Pa (0.1 if it clips)
note = sprintf('near field at %s, L = %g mm', where, L_mm);
m = measure_labD(tag, 'nearfield', 'Nav', Nav, 'NexusVperPa', NexusVperPa, 'note', note);

%% 4. Before you leave: fill in labD_dims.m, then run the analysis
% In labD_dims.m, list every vent tag with its length and number of open
% vents, and every near-field cone/vent pair, or they are left out.
r = analyse_labD;
