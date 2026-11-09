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

%% 0. Before the first run
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end
edit project_dims        % fill in: UMIK label, temperature, distances, panel no.
test_project             % no hardware: must print PASS
% Model curves come from `python3 model_curves.py` (already in ../model/).
return

%% R1. On axis, 0 deg: woofer / mid+tweeter / all  (~4 min)
% Start: Out 2 MUTED. Beeps 1: unmute Out 2, mute Out 1. Beeps 2: unmute Out 1.
m = measure_project('R1_split_0', 0, {'woofer', 'midtw', 'all'}, 'note', 'reference run');
% Check in the printout: woofer - midtw offset within +-1 dB, sum check < 0.5 dB.

%% R2. On axis, 0 deg: midrange / tweeter / all  (~4 min)
% Start: Out 1 MUTED, TWEETER lead off at the board. Beeps 1: tweeter on,
% midrange off. Beeps 2: midrange back on, unmute Out 1.
m = measure_project('R2_units_0', 0, {'mid', 'tw', 'all'});

%% R3. Polarity checks, 0 deg: all / woofer inverted / tweeter swapped  (~4 min)
% Start: all normal. Beeps 1: tick Out 1 INVERT. Beeps 2: untick it and swap
% the tweeter's + and - at the board. AFTERWARDS: swap the tweeter back!
% Expected (model): woofer inverted -> notch ~329 Hz, about -21 dB;
%                   tweeter swapped -> notch ~3.9 kHz, about -14 dB.
m = measure_project('R3_flip_0', 0, {'all', 'flipW', 'flipT'});

%% R4. 30 deg: woofer / mid+tweeter / all  (~4 min)
% Turn the system 30 deg (same direction as in Lab E). Same switching as R1.
m = measure_project('R4_split_30', 30, {'woofer', 'midtw', 'all'});

%% R5. Back to 0 deg: repeat of R1 (drift / placement check)  (~4 min)
% Turn back to 0 deg, tweeter polarity normal, no invert. Same switching as R1.
% The 'all' curve must sit on R1's within a few tenths of a dB.
m = measure_project('R5_repeat_0', 0, {'woofer', 'midtw', 'all'}, 'note', 'repeat of R1');
r1 = load(fullfile('..', 'data', 'project_R1_split_0.mat'));
d = 20*log10(abs(m.H(:,3))) - 20*log10(abs(r1.H(:,3)));
k = m.fn >= 150 & m.fn <= 15000;
fprintf('R5 vs R1, all three: median %+.2f dB, worst %.2f dB\n', median(d(k)), max(abs(d(k))));

%% 6. Optional: a design change (e.g. Out 1 gain) -> new tag, note what changed
% m = measure_project('R6_gain_0', 0, {'woofer', 'midtw', 'all'}, 'note', 'Out 1 gain -3.5 dB');

%% 7. Before you leave
% Save the MiniDSP configuration to a file, photograph the board, copy
% ../data/ to the USB stick, delete our files from the lab PC.
