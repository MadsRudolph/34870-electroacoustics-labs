%% Lab C - Part 2: sensitivity of each microphone at one frequency
% *What was measured.* Each microphone was put in each of the three GRAS 42AG
% calibrators (c1, c2, c3), at 250 Hz and at 1 kHz. The calibrator makes a known
% sound pressure (from its certificate), the course function Calibrate measures
% the rms voltage, and
%
%   M = v_rms / p_rms / G_Nex        [V/Pa],   p_rms = 20e-6 * 10^(SPL/20)
%
% Then the brief divides by the system response from Part 1:
%
%   M = Calibrate(f, SPL, 1) / abs(H_21_ref(f))
%
% *The mistake on the lab PC.* abs(H_21_ref) was typed as its dB value
% (-0.0036 instead of 0.9996), so the stored numbers are
%
%   M_stored = Calibrate(...) / 0.003607      (250 Hz)
%   M_stored = Calibrate(...) / 0.003672      (1 kHz)
%
% Multiplying back by the typed number recovers the Calibrate output, and then
% dividing by the real abs(H_21_ref) gives the sensitivity the brief intended.
%
% *Naming.* M1c2_1kHz = microphone 1, calibrator 2, 1 kHz. Which microphone is
% which type is found in Part 3 from the shape of the response.

clear; close all
here   = fileparts(mfilename('fullpath'));
rawdir = fullfile(here, '..', 'raw data');                % untouched copy of the lab PC folder
outdir = fullfile(here, 'results');
figdir = fullfile(here, '..', 'figures');

raw2 = load(fullfile(rawdir, 'datas_part2.mat'));            % the 12 stored values
p1   = load(fullfile(outdir, 'part1_results.mat'));          % run part1_system_reference first

%% The stored values, as they came off the lab PC
% Rows: calibrator 1, 2, 3. They are in "V/Pa" but about 3, which is impossible
% for a condenser microphone (they are around 10 mV/Pa).

stored_M1_250  = [raw2.M1c1_250Hz; raw2.M1c2_250Hz; raw2.M1c3_250Hz];
stored_M1_1000 = [raw2.M1c1_1kHz;  raw2.M1c2_1kHz;  raw2.M1c3_1kHz];
stored_M2_250  = [raw2.M2c1_250Hz; raw2.M2c2_250Hz; raw2.M2c3_250Hz];
stored_M2_1000 = [raw2.M2c1_1kHz;  raw2.M2c2_1kHz;  raw2.M2c3_1kHz];

stored = table(stored_M1_250, stored_M1_1000, stored_M2_250, stored_M2_1000, ...
               'RowNames', {'c1', 'c2', 'c3'})

%% Correct them
%   M = M_stored * abs(typed) / abs(H_21_ref)

M1_250  = stored_M1_250  * abs(p1.typed_250)  / p1.H_ref_250;
M1_1000 = stored_M1_1000 * abs(p1.typed_1000) / p1.H_ref_1000;
M2_250  = stored_M2_250  * abs(p1.typed_250)  / p1.H_ref_250;
M2_1000 = stored_M2_1000 * abs(p1.typed_1000) / p1.H_ref_1000;

sensitivity_mV_per_Pa = table(M1_250*1e3, M1_1000*1e3, M2_250*1e3, M2_1000*1e3, ...
    'VariableNames', {'Mic1_250Hz', 'Mic1_1kHz', 'Mic2_250Hz', 'Mic2_1kHz'}, ...
    'RowNames', {'c1', 'c2', 'c3'})

%% Repeatability: how much the three calibrators disagree
% Mean, standard deviation and the standard deviation relative to the mean
% for each column (microphone x frequency):
%
%   s_rel = std / mean * 100 %

all_M = [M1_250, M1_1000, M2_250, M2_1000] * 1e3;          % mV/Pa
mean_mV_per_Pa = mean(all_M);
std_mV_per_Pa  = std(all_M);
std_percent    = std_mV_per_Pa ./ mean_mV_per_Pa * 100;
mean_dB_re_1V_per_Pa = 20*log10(mean_mV_per_Pa/1e3);

statistics = table(mean_mV_per_Pa', std_mV_per_Pa', std_percent', mean_dB_re_1V_per_Pa', ...
    'VariableNames', {'mean_mV_per_Pa', 'std_mV_per_Pa', 'std_percent', 'mean_dB_re_1V_per_Pa'}, ...
    'RowNames', {'Mic1 250 Hz', 'Mic1 1 kHz', 'Mic2 250 Hz', 'Mic2 1 kHz'})

%% 250 Hz against 1 kHz
% Both microphones are flat between 250 Hz and 1 kHz (Part 3 shows less than
% 0.1 dB difference), so both frequencies should give the same sensitivity.
% They don't:
%
%   difference = 20*log10( M_250 / M_1000 )

diff_Mic1_dB = 20*log10(mean(M1_250) / mean(M1_1000))
diff_Mic2_dB = 20*log10(mean(M2_250) / mean(M2_1000))

%%
% The offset is the same (about -0.37 dB, 4 %) for both microphones and all three
% calibrators, so it is systematic: it belongs to the 250 Hz method, not to the
% microphones. The likely cause is Calibrate.m itself: at 250 Hz it only sums six
% FFT bins that end at the nominal frequency (it was written for a 251.2 Hz
% pistonphone), while at 1 kHz it sums seventeen bins from 999 to 1015 Hz. A
% calibrator tone slightly above 250 Hz loses part of its energy outside the
% 250 Hz window. The raw time signals were not saved, so this cannot be proven
% from the data; it is the most likely explanation.
%
% For the metrology question this is the difference between
%
% * repeatability: same microphone, same method, three calibrators: ~0.2 %
% * reproducibility: a different method (250 Hz vs 1 kHz): ~4 %
%
% and it shows that a small spread says nothing about the true value.
% The 1 kHz values are used from here on.

M1 = mean(M1_1000)
M2 = mean(M2_1000)

%% Plot
fig = figure('Name', 'Part 2', 'Color', 'w');
theme(fig, 'light');
plot(1:3, M1_1000*1e3, 'o-', 'LineWidth', 1.4, 'Color', [0.75 0.22 0.17], 'DisplayName', 'Mic 1, 1 kHz'); hold on
plot(1:3, M1_250*1e3,  's--', 'LineWidth', 1.4, 'Color', [0.75 0.22 0.17], 'DisplayName', 'Mic 1, 250 Hz')
plot(1:3, M2_1000*1e3, 'o-', 'LineWidth', 1.4, 'Color', [0.12 0.31 0.61], 'DisplayName', 'Mic 2, 1 kHz')
plot(1:3, M2_250*1e3,  's--', 'LineWidth', 1.4, 'Color', [0.12 0.31 0.61], 'DisplayName', 'Mic 2, 250 Hz')
grid on; xlim([0.7 3.3]); xticks(1:3); xticklabels({'calibrator 1', 'calibrator 2', 'calibrator 3'})
ylabel('sensitivity [mV/Pa]'); legend('Location', 'east')
title('Part 2: single-frequency sensitivity (corrected)')
exportgraphics(fig, fullfile(figdir, 'labC_part2_sensitivity.png'), 'Resolution', 200);

save(fullfile(outdir, 'part2_results.mat'), 'M1_250', 'M1_1000', 'M2_250', 'M2_1000', 'M1', 'M2', 'statistics', 'diff_Mic1_dB', 'diff_Mic2_dB');
