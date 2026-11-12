%% Task 3: measuring the built System D in the anechoic chamber
% Open this file in the MATLAB editor on the lab PC. Each run is its own
% section: click inside it and press "Run Section" (Ctrl+Enter). Every run
% is saved to ../data/project_<tag>.mat at once (a repeated tag gets _2, _3),
% then plotted against the model (dashed, shifted by the fitted level).
%
% Plug the UMIK into USB BEFORE starting MATLAB, or it is not found.
% One run = up to 3 states with ~30 s of beeps between them: switch during
% the beeps. Only states inside one run share a phase reference.
% Do not touch the amplifier volume or move the microphone between runs.
% The states are selected on the chamber's SWITCHBOARD: woofer, midrange and
% tweeter each ON/OFF (as in Lab E). Not the MiniDSP mute, not the cables.
% Every run is plotted and saved to ../figures/<tag>.png automatically.
% All graphs again at any time:   plot_project
% One run, renaming a state that was not switched in time:
%   plot_project('R2_units_0', 'labels', {'mid', 'tw', 'tw (not switched)'})
%
% The first line of every section only makes MATLAB find the helper files in core/
% (also right after a MATLAB restart): leave it in.
% Newer, with a graph + verdict after every step: ../kit/labgui.m (buttons) or ../kit/lab_run.m.

%% 0. Before the first run
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
addpath('core', 'tests', fullfile('..', 'kit', 'core'));   % the helper files (core/ = called automatically)
edit project_dims        % fill in: UMIK label, temperature, distances, panel no.
test_project             % no hardware: must print PASS
% Model curves come from `python3 model_curves.py` (already in ../model/).
return

%% R1. On axis, 0 deg: woofer / mid+tweeter / all  (~4 min)
% Switchboard: start woofer ON, mid OFF, tweeter OFF. Beeps 1: woofer OFF, mid ON,
% tweeter ON. Beeps 2: woofer ON (all three ON).
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_project('R1_split_0', 0, {'woofer', 'midtw', 'all'}, 'note', 'reference run');
% Check in the printout: woofer - midtw offset within +-1 dB, sum check < 0.5 dB.

%% R2. On axis, 0 deg: midrange / tweeter / all  (~4 min)
% Switchboard: start woofer OFF, mid ON, tweeter OFF. Beeps 1: mid OFF, tweeter ON.
% Beeps 2: woofer ON, mid ON (all three ON).
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_project('R2_units_0', 0, {'mid', 'tw', 'all'});

%% R3. Polarity checks, 0 deg: all / woofer inverted / tweeter swapped  (~4 min)
% Start: all normal. Beeps 1: tick Out 1 INVERT. Beeps 2: untick it and swap
% the tweeter's + and - at the board. AFTERWARDS: swap the tweeter back!
% Expected (model): woofer inverted -> notch ~329 Hz, about -21 dB;
%                   tweeter swapped -> notch ~3.9 kHz, about -14 dB.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_project('R3_flip_0', 0, {'all', 'flipW', 'flipT'});

%% R4. 30 deg: woofer / mid+tweeter / all  (~4 min)
% Turn the system 30 deg (same direction as in Lab E). Same switching as R1.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_project('R4_split_30', 30, {'woofer', 'midtw', 'all'});

%% R5. Back to 0 deg: repeat of R1 (drift / placement check)  (~4 min)
% Turn back to 0 deg, tweeter polarity normal, no invert. Same switching as R1.
% The 'all' curve must sit on R1's within a few tenths of a dB.
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end, addpath('core', fullfile('..', 'kit', 'core'))   % finds the helpers
m = measure_project('R5_repeat_0', 0, {'woofer', 'midtw', 'all'}, 'note', 'repeat of R1');
r1 = load(fullfile('..', 'data', 'project_R1_split_0.mat'));     % the good R1 (try 3, 15:17)
d = 20*log10(abs(m.H(:,3))) - 20*log10(abs(r1.H(:,3)));
k = m.fn >= 150 & m.fn <= 15000;
fprintf('R5 vs R1, all: median %+.2f dB, worst %.2f dB\n', median(d(k)), max(abs(d(k))));

%% 6. Optional: a design change (e.g. Out 1 gain) -> new tag, note what changed
% m = measure_project('R6_gain_0', 0, {'woofer', 'midtw', 'all'}, 'note', 'Out 1 gain -3.5 dB');

%% 7. Before you leave
% Save the MiniDSP configuration to a file, photograph the board, copy
% ../data/ to the USB stick, delete our files from the lab PC.
