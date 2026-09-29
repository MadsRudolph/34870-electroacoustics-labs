%% Lab C - Part 3: frequency response of the microphones with the actuator
% *What was measured.* The electrostatic actuator sat on top of the diaphragm
% and pushed on it with a force that is (almost) the same at every frequency.
% The multitone drove the actuator amplifier (GRAS 14AA) and was recorded on AI0;
% the microphone output (through the Nexus) went to AI1. For each microphone
%
%   H_21 = V_AI1 / V_AI0 = microphone voltage / actuator drive voltage
%
% Dividing by the Part 1 reference removes the NI card and the Nexus:
%
%   H_pv = H_21 ./ H_21_ref
%
% H_pv only has the right *shape*; its level depends on how the actuator sat.
% The level comes from the Part 2 sensitivity.
%
% *Noise floor.* Same measurement with the actuator amplifier switched off,
% Nav = 4 and Nav = 64, only on Mic 2.

clear; close all
here   = fileparts(mfilename('fullpath'));
rawdir = fullfile(here, '..', 'raw data');                % untouched copy of the lab PC folder
outdir = fullfile(here, 'results');
figdir = fullfile(here, '..', 'figures');

raw3 = load(fullfile(rawdir, 'datas_part3.mat'));    % H_21_m1, H_21_m2, noisefloor_m2_nav4, noisefloor_m2_nav64
p1   = load(fullfile(outdir, 'part1_results.mat'));  % fn, H_21_ref (top two points already removed)
p2   = load(fullfile(outdir, 'part2_results.mat'));  % M1, M2 at 1 kHz

fn = p1.fn;
H_21_m1  = raw3.H_21_m1(p1.use);
H_21_m2  = raw3.H_21_m2(p1.use);
noise_4  = raw3.noisefloor_m2_nav4(p1.use);
noise_64 = raw3.noisefloor_m2_nav64(p1.use);

%% Is the signal far enough above the noise?
% The noise spectra were computed the same way as H_21 (microphone channel over
% drive channel), so they can be compared directly:
%
%   SNR = 20*log10( |H_21| / |noise| )
%
% Averaging 16 times more (Nav 4 -> 64) should lower random noise by
% 10*log10(16) = 12 dB.

SNR_worst_Nav4_dB  = min(20*log10(abs(H_21_m2) ./ abs(noise_4)))
SNR_worst_Nav64_dB = min(20*log10(abs(H_21_m2) ./ abs(noise_64)))
averaging_gain_dB  = median(20*log10(abs(noise_4) ./ abs(noise_64)))

fig = figure('Name', 'Part 3 noise', 'Color', 'w');
theme(fig, 'light');
semilogx(fn, 20*log10(abs(H_21_m2)), 'k-', 'LineWidth', 1.6); hold on
semilogx(fn, 20*log10(abs(noise_4)), '.-', 'Color', [0.85 0.45 0.1])
semilogx(fn, 20*log10(abs(noise_64)), '.-', 'Color', [0.2 0.55 0.3])
grid on; xlim([20 45e3]); ylim([-130 -10])
xlabel('Frequency [Hz]'); ylabel('microphone / drive [dB]')
legend('Mic 2, actuator on', 'noise, Nav = 4', 'noise, Nav = 64', 'Location', 'southwest')
title('Part 3b: signal against noise floor')
exportgraphics(fig, fullfile(figdir, 'labC_part3_noise_floor.png'), 'Resolution', 200);

%%
% The worst case is at 20 Hz (room noise); everywhere else the signal is
% 60-90 dB above the noise, so the noise has no effect on the responses.

%% Remove the measurement system

H_pv_1 = H_21_m1 ./ p1.H_21_ref;
H_pv_2 = H_21_m2 ./ p1.H_21_ref;

%% Which microphone is which?
% Normalise both to 0 dB in the flat part (100-500 Hz) and compare the shapes.

flat = fn >= 100 & fn <= 500;
level_1 = mean(abs(H_pv_1(flat)));
level_2 = mean(abs(H_pv_2(flat)));

shape_1_dB = 20*log10(abs(H_pv_1) / level_1);
shape_2_dB = 20*log10(abs(H_pv_2) / level_2);

at_10kHz_dB = [interp1(fn, shape_1_dB, 10e3), interp1(fn, shape_2_dB, 10e3)]
at_20kHz_dB = [interp1(fn, shape_1_dB, 20e3), interp1(fn, shape_2_dB, 20e3)]

%%
% * *Mic 1* is flat, rises a little before the resonance and then falls. A flat
%   actuator (= pressure) response is what a *pressure-field* microphone is
%   designed for: Mic 1 is the *B&K 4134*.
% * *Mic 2* is already about 8 dB down at 20 kHz. That is a deliberately
%   over-damped diaphragm: in a free field the pressure build-up in front of the
%   microphone rises at high frequencies and cancels this fall. Mic 2 is the
%   *free-field* microphone, the *B&K 4133*.

%% Scale to absolute sensitivity
% The calibrator gives the sensitivity at 1 kHz (Part 2). Scale each shape so
% that it passes through that value at 1 kHz:
%
%   M(f) = M_1kHz * H_pv(f) / |H_pv(1 kHz)|
%
% A calibrator is a small closed coupler, so it measures the *pressure*
% sensitivity, just like the actuator. At 1 kHz the free-field correction of a
% 1/2" microphone is practically 0 dB, so the same value is used for both.

M_1 = p2.M1 * H_pv_1 / abs(H_pv_1(fn == 1000));
M_2 = p2.M2 * H_pv_2 / abs(H_pv_2(fn == 1000));

fig = figure('Name', 'Part 3 responses', 'Color', 'w');
theme(fig, 'light');
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
nexttile
semilogx(fn, 20*log10(abs(M_1)), '.-', 'LineWidth', 1.4, 'Color', [0.75 0.22 0.17]); hold on
semilogx(fn, 20*log10(abs(M_2)), '.-', 'LineWidth', 1.4, 'Color', [0.12 0.31 0.61])
grid on; xlim([20 45e3]); ylim([-52 -36])
ylabel('sensitivity [dB re 1 V/Pa]')
legend('Mic 1 (B&K 4134, pressure field)', 'Mic 2 (B&K 4133, free field)', 'Location', 'southwest')
title('Part 3c: actuator response scaled with the 1 kHz calibration')
nexttile
semilogx(fn, angle(H_pv_1)*180/pi, '.-', 'LineWidth', 1.4, 'Color', [0.75 0.22 0.17]); hold on
semilogx(fn, angle(H_pv_2)*180/pi, '.-', 'LineWidth', 1.4, 'Color', [0.12 0.31 0.61])
yline(-90, 'k:')
grid on; xlim([20 45e3]); ylim([-180 20]); yticks(-180:45:0)
ylabel('phase [deg]'); xlabel('Frequency [Hz]')
exportgraphics(fig, fullfile(figdir, 'labC_part3_responses.png'), 'Resolution', 200);

%% Resonance frequency from the phase (course slides, lectures 4 and 6)
% Below resonance the diaphragm is stiffness controlled (phase 0), above it is
% mass controlled (phase -180). Exactly at resonance the phase is -90 deg:
%
%   f_s = the frequency where angle(H_pv) = -90 deg
%
% Between two measured points we interpolate on a log-frequency axis. Only the
% part above 5 kHz is used, where the phase falls monotonically.

ph_1 = angle(H_pv_1)*180/pi;
ph_2 = angle(H_pv_2)*180/pi;
hi   = fn > 5000;

fs_1 = exp(interp1(ph_1(hi), log(fn(hi)), -90))
fs_2 = exp(interp1(ph_2(hi), log(fn(hi)), -90))

%% Q factor from the magnitude
% For a second-order system the magnitude at resonance, relative to the flat
% low-frequency level, is exactly Q:
%
%   Q = |H_pv(f_s)| / |H_pv(low f)|

Q_1 = 10^(interp1(log(fn), shape_1_dB, log(fs_1)) / 20)
Q_2 = 10^(interp1(log(fn), shape_2_dB, log(fs_2)) / 20)

%% Cross-check: fit a second-order model to the whole curve
% The two readings above each use only one point. As a check, fit
%
%   H(f) = G / (1 - (f/f_s)^2 + j*(f/f_s)/Q)
%
% to the complex H_pv from 100 Hz to 42 kHz by least squares (fminsearch).
% G is a complex gain, so a phase offset between measurement and model does
% not matter. If the fit agrees with the readings, they can be trusted.

band = fn >= 100;
x_1 = fn(band); y_1 = H_pv_1(band) / level_1;
x_2 = fn(band); y_2 = H_pv_2(band) / level_2;

model = @(p, f) 1 ./ (1 - (f/p(1)).^2 + 1j*(f/p(1))/p(2));
gain  = @(p, f, y) (model(p, f)' * y) / (model(p, f)' * model(p, f));     % best complex G for given f_s, Q
cost  = @(p, f, y) sum(abs(y - gain(p, f, y)*model(p, f)).^2 ./ abs(model(p, f)).^2);

opts  = optimset('TolX', 1e-9, 'TolFun', 1e-12, 'MaxFunEvals', 5000);
fit_1 = fminsearch(@(p) cost(p, x_1, y_1), [fs_1 Q_1], opts);
fit_2 = fminsearch(@(p) cost(p, x_2, y_2), [fs_2 Q_2], opts);

results = table([fs_1; fs_2], [fit_1(1); fit_2(1)], [Q_1; Q_2], [fit_1(2); fit_2(2)], ...
    'VariableNames', {'fs_phase_Hz', 'fs_fit_Hz', 'Q_magnitude', 'Q_fit'}, ...
    'RowNames', {'Mic 1 (4134)', 'Mic 2 (4133)'})

save(fullfile(outdir, 'part3_results.mat'), 'fn', 'H_pv_1', 'H_pv_2', 'M_1', 'M_2', 'level_1', 'level_2', ...
     'fs_1', 'fs_2', 'Q_1', 'Q_2', 'fit_1', 'fit_2', 'results');
