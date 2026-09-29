%% Lab C - Analysis: condenser microphone model from f_s and Q
% The brief gives the microphone data (the same for both types) and asks us to
% find the backplate's acoustic mass M_AS and resistance R_AS from the measured
% f_s and Q, then put the model in LTspice. This script does the hand
% calculation, so the LTspice numbers can be checked, and draws the model on
% top of the measurement.
%
% Mechanical side of the diaphragm (all in series, driven by the actuator force):
%
%   mass       M_MT = M_MD + S_D^2 (M_A1 + M_AS)
%   resistance R_MT = S_D^2 R_AS                  (R_MD = 0 in the brief)
%   compliance C_MT = C_MD in series with the back volume C_AB / S_D^2
%
% The output voltage follows the diaphragm displacement, so
%
%   e / p = M_model / (1 - (f/f_s)^2 + j (f/f_s)/Q)
%
% with f_s = 1/(2 pi sqrt(M_MT C_MT)) and Q = sqrt(M_MT/C_MT) / R_MT.

clear; close all
here   = fileparts(mfilename('fullpath'));
outdir = fullfile(here, 'results');
figdir = fullfile(here, '..', 'figures');
p3 = load(fullfile(outdir, 'part3_results.mat'));   % run parts 1-3 first

%% Data from the brief

rho = 1.18;          % air density [kg/m^3]
c   = 344;           % speed of sound [m/s]
x0  = 20.77e-6;      % diaphragm to backplate distance [m]
E   = 200;           % polarisation voltage [V]
d   = 8.95e-3;       % effective diaphragm diameter [m]
MMD = 1.5e-6;        % diaphragm mass [kg]
CMD = 0.02e-3;       % diaphragm compliance [m/N]
Vb  = 126.4e-9;      % back volume [m^3]

%% Constants that do not depend on the measurement
%   S_D = pi a^2,   C_AB = V_B / (rho c^2),   M_A1 = 0.6133 rho / (pi a)

a   = d/2;
SD  = pi*a^2
CAB = Vb/(rho*c^2)
MA1 = 0.6133*rho/(pi*a)

%%
% Total compliance: the diaphragm and the air in the back volume are both
% springs acting on the diaphragm, in series
%
%   1/C_MT = 1/C_MD + S_D^2/C_AB

CMT = 1/(1/CMD + SD^2/CAB)

%%
% Model sensitivity (Leach), and the rest capacitance:
%
%   M_model = E C_MT S_D / x0,   C_E0 = eps0 S_D / x0

M_model_mV_per_Pa = E*CMT*SD/x0 * 1e3
CE0_pF = 8.854e-12*SD/x0 * 1e12

%%
% The brief's appendix warns that this simple model gives a sensitivity a bit
% below the real one; that is accepted, the shape around resonance is what counts.

%% Backplate mass and resistance from the measured f_s and Q
% f_s fixes the total mass, Q fixes the resistance:
%
%   M_MT = 1 / ((2 pi f_s)^2 C_MT)
%   M_AS = (M_MT - M_MD)/S_D^2 - M_A1
%   R_AS = sqrt(M_MT/C_MT) / Q / S_D^2
%
% Mic 1 (B&K 4134, pressure field), f_s and Q read off as in the slides:

fs_1 = p3.fs_1
Q_1  = p3.Q_1
MMT_1 = 1/((2*pi*fs_1)^2*CMT);
MAS_1 = (MMT_1 - MMD)/SD^2 - MA1
RAS_1 = sqrt(MMT_1/CMT)/Q_1/SD^2

%%
% Mic 2 (B&K 4133, free field):

fs_2 = p3.fs_2
Q_2  = p3.Q_2
MMT_2 = 1/((2*pi*fs_2)^2*CMT);
MAS_2 = (MMT_2 - MMD)/SD^2 - MA1
RAS_2 = sqrt(MMT_2/CMT)/Q_2/SD^2

%%
% The lines to paste into the LTspice schematic (ltspice/LabC_CondenserMics.asc):

param_line = sprintf('.param fs34=%.0f Q34=%.3f fs33=%.0f Q33=%.3f', fs_1, Q_1, fs_2, Q_2)

%% Model against measurement
% Both curves are normalised to 0 dB in the flat part (100-500 Hz), so only the
% shape is compared. The measured phase is referred to 0 deg at low frequency.

fn = p3.fn;
model_1 = 1 ./ (1 - (fn/fs_1).^2 + 1j*(fn/fs_1)/Q_1);
model_2 = 1 ./ (1 - (fn/fs_2).^2 + 1j*(fn/fs_2)/Q_2);
fitm_1  = 1 ./ (1 - (fn/p3.fit_1(1)).^2 + 1j*(fn/p3.fit_1(1))/p3.fit_1(2));
fitm_2  = 1 ./ (1 - (fn/p3.fit_2(1)).^2 + 1j*(fn/p3.fit_2(1))/p3.fit_2(2));
meas_1  = p3.H_pv_1 / p3.level_1;
meas_2  = p3.H_pv_2 / p3.level_2;

red = [0.75 0.22 0.17]; blue = [0.12 0.31 0.61];
fig = figure('Name', 'Model vs measurement', 'Color', 'w', 'Position', [100 100 900 700]);
theme(fig, 'light');
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
nexttile
semilogx(fn, 20*log10(abs(meas_1)), 'o', 'Color', red, 'MarkerSize', 4); hold on
semilogx(fn, 20*log10(abs(model_1)), '-', 'Color', red, 'LineWidth', 1.4)
semilogx(fn, 20*log10(abs(fitm_1)), ':', 'Color', red, 'LineWidth', 1.4)
semilogx(fn, 20*log10(abs(meas_2)), 'o', 'Color', blue, 'MarkerSize', 4)
semilogx(fn, 20*log10(abs(model_2)), '-', 'Color', blue, 'LineWidth', 1.4)
semilogx(fn, 20*log10(abs(fitm_2)), ':', 'Color', blue, 'LineWidth', 1.4)
grid on; xlim([100 45e3]); ylim([-16 3])
ylabel('response re 100-500 Hz [dB]')
legend('Mic 1 measured', sprintf('Mic 1 model, f_s = %.1f kHz, Q = %.2f (slides)', fs_1/1e3, Q_1), ...
       sprintf('Mic 1 fit, f_s = %.1f kHz, Q = %.2f', p3.fit_1(1)/1e3, p3.fit_1(2)), ...
       'Mic 2 measured', sprintf('Mic 2 model, f_s = %.1f kHz, Q = %.2f (slides)', fs_2/1e3, Q_2), ...
       sprintf('Mic 2 fit, f_s = %.1f kHz, Q = %.2f', p3.fit_2(1)/1e3, p3.fit_2(2)), 'Location', 'southwest')
title('Measured actuator response against the second-order model')
nexttile
semilogx(fn, angle(meas_1)*180/pi, 'o', 'Color', red, 'MarkerSize', 4); hold on
semilogx(fn, angle(model_1)*180/pi, '-', 'Color', red, 'LineWidth', 1.4)
semilogx(fn, angle(fitm_1)*180/pi, ':', 'Color', red, 'LineWidth', 1.4)
semilogx(fn, angle(meas_2)*180/pi, 'o', 'Color', blue, 'MarkerSize', 4)
semilogx(fn, angle(model_2)*180/pi, '-', 'Color', blue, 'LineWidth', 1.4)
semilogx(fn, angle(fitm_2)*180/pi, ':', 'Color', blue, 'LineWidth', 1.4)
yline(-90, 'k:')
grid on; xlim([100 45e3]); ylim([-180 10]); yticks(-180:45:0)
ylabel('phase [deg]'); xlabel('Frequency [Hz]')
exportgraphics(fig, fullfile(figdir, 'labC_model_vs_measurement.png'), 'Resolution', 200);

%% How good is the model?
% Largest difference between model and measurement from 100 Hz to 42 kHz:

worst_dB_Mic1  = max(abs(20*log10(abs(meas_1 ./ model_1))))
worst_deg_Mic1 = max(abs(angle(meas_1 ./ model_1)*180/pi))
worst_dB_Mic2  = max(abs(20*log10(abs(meas_2 ./ model_2))))
worst_deg_Mic2 = max(abs(angle(meas_2 ./ model_2)*180/pi))

%%
% *Mic 1 (4134)* is a textbook second-order system: model and measurement agree
% within about 1 dB and a few degrees, and the slide reading and the fit give the
% same f_s and Q within 3 %.
%
% *Mic 2 (4133)* also follows the model up to its resonance: aligned at 1 kHz the
% shape agrees within 0.5 dB and 5 deg up to 20 kHz (see the LTspice section below).
% Above resonance it departs by up to 1.6 dB and 19 deg: the measured phase falls
% slowly between about 12 and 25 kHz and then faster than the model. A free-field
% capsule gets its heavy damping from the air film between the diaphragm and a
% slotted, perforated backplate, and that damping depends on frequency, so one
% lumped R_AS and M_AS cannot fit every region at once. This is also why the
% -90 deg reading (22.9 kHz) and the whole-curve fit (21.1 kHz) differ by 9 %.
% Use the slide values as the brief asks and mention the difference as a
% limitation of the lumped model.

%% LTspice against measurement
% The LTspice schematic (ltspice/LabC_CondenserMics.asc) holds the full
% three-domain circuit with the f_s and Q found above. It is run headless and
% exported with
%
%   python3 ltspice/gen_labC_ltspice.py --export --verify
%
% which writes results/ltspice_labC.csv. Here the LTspice output is plotted in
% absolute units (dB re 1 V/Pa) on top of the calibrated measurement, so the
% sensitivity difference the brief's appendix talks about is visible too.

p2 = load(fullfile(outdir, 'part2_results.mat'));
lt = readtable(fullfile(outdir, 'ltspice_labC.csv'));
lt_34 = complex(lt.re_out34, lt.im_out34);          % 4134 = Mic 1
lt_33 = complex(lt.re_out33, lt.im_out33);          % 4133 = Mic 2

%%
% Low-frequency level: model against calibration (the model has one fixed
% sensitivity for both capsules, 11.14 mV/Pa):
%
%   difference = 20*log10( M_measured / M_model )

diff_Mic1_dB = 20*log10(p2.M1 / (M_model_mV_per_Pa/1e3))
diff_Mic2_dB = 20*log10(p2.M2 / (M_model_mV_per_Pa/1e3))

fig = figure('Name', 'LTspice vs measurement', 'Color', 'w', 'Position', [100 100 900 700]);
theme(fig, 'light');
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
nexttile
semilogx(fn, 20*log10(abs(p3.M_1)), 'o', 'Color', red, 'MarkerSize', 4); hold on
semilogx(lt.f_Hz, 20*log10(abs(lt_34)), '-', 'Color', red, 'LineWidth', 1.4)
semilogx(fn, 20*log10(abs(p3.M_2)), 'o', 'Color', blue, 'MarkerSize', 4)
semilogx(lt.f_Hz, 20*log10(abs(lt_33)), '-', 'Color', blue, 'LineWidth', 1.4)
grid on; xlim([20 45e3]); ylim([-54 -36])
ylabel('sensitivity [dB re 1 V/Pa]')
legend('Mic 1 (4134) measured', 'Mic 1 (4134) LTspice', 'Mic 2 (4133) measured', 'Mic 2 (4133) LTspice', 'Location', 'southwest')
title('LTspice model against the calibrated measurement')
nexttile
semilogx(fn, angle(meas_1)*180/pi, 'o', 'Color', red, 'MarkerSize', 4); hold on
semilogx(lt.f_Hz, angle(lt_34)*180/pi, '-', 'Color', red, 'LineWidth', 1.4)
semilogx(fn, angle(meas_2)*180/pi, 'o', 'Color', blue, 'MarkerSize', 4)
semilogx(lt.f_Hz, angle(lt_33)*180/pi, '-', 'Color', blue, 'LineWidth', 1.4)
yline(-90, 'k:')
grid on; xlim([20 45e3]); ylim([-180 10]); yticks(-180:45:0)
ylabel('phase [deg]'); xlabel('Frequency [Hz]')
exportgraphics(fig, fullfile(figdir, 'labC_ltspice_vs_measurement.png'), 'Resolution', 200);

%%
% The phase of the LTspice output is shown without any 180 deg shift: the
% actuator source in the schematic is entered as "AC 1 180", which already
% takes care of the ground convention.

save(fullfile(outdir, 'part4_results.mat'), 'SD', 'CAB', 'MA1', 'CMT', 'M_model_mV_per_Pa', 'CE0_pF', ...
     'fs_1', 'Q_1', 'MAS_1', 'RAS_1', 'fs_2', 'Q_2', 'MAS_2', 'RAS_2', 'param_line', 'diff_Mic1_dB', 'diff_Mic2_dB', ...
     'worst_dB_Mic1', 'worst_deg_Mic1', 'worst_dB_Mic2', 'worst_deg_Mic2');
