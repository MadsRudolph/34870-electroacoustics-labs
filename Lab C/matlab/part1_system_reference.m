%% Lab C - Part 1: the measurement system on its own
% *What was measured.* The NI card's output AO0 went straight into input AI0
% and, through the Nexus amplifier (gain 1), into input AI1. No microphone.
%
% *Why.* Everything we measure later passes through the NI card and the Nexus.
% Their own transfer function
%
%   H_21_ref = V_AI1 / V_AI0
%
% is what we divide out in Part 2 (at 250 Hz and 1 kHz) and in Part 3 (at every
% frequency). Ideally it is exactly 1 (0 dB, 0 deg).
%
% *Data.* 'raw data/datas_part1.mat' and 'raw data/all.mat', copied unchanged from
% the lab PC. They are only read here, never written: everything is loaded
% into the structs |raw1| and |ws| so no variable in your workspace is overwritten.

clear; close all
here   = fileparts(mfilename('fullpath'));
rawdir = fullfile(here, '..', 'raw data');                % untouched copy of the lab PC folder
outdir = fullfile(here, 'results');
figdir = fullfile(here, '..', 'figures');

raw1 = load(fullfile(rawdir, 'datas_part1.mat'));   % H_21_ref, H_21_250, H_21_1000
ws   = load(fullfile(rawdir, 'all.mat'), 'fn');     % the frequency vector is only in the workspace dump

%% The frequency axis, and why the top two points are thrown away
% The multitone has 6 lines per octave from 20 Hz to f2 = 60 kHz (70 lines).
% The NI card samples at fs = 96 kHz, so nothing above the Nyquist frequency
%
%   f_Nyq = fs/2 = 48 kHz
%
% can be measured. The 47.8 kHz line sits on the anti-aliasing filter edge and
% the 53.6 kHz line is really a mirror image of 42.4 kHz. Both are dropped.

fn_all  = ws.fn(:);
f_Nyq   = 96000/2
use     = fn_all < 45000;
fn      = fn_all(use);
dropped = fn_all(~use)'

H_21_ref = raw1.H_21_ref(use);

%% Look at it
% Magnitude within 0.005 dB of 0 dB up to 5 kHz, rising to +0.14 dB at 42 kHz
% (the Nexus/card filters). The phase falls linearly with frequency to -48 deg at 42 kHz: that is a pure time
% delay between the two input channels, which is why Part 3 needs this correction.
%
%   delay = -phase / (360 * f)

delay_us = -angle(H_21_ref(end))*180/pi / (360*fn(end)) * 1e6

fig = figure('Name', 'Part 1', 'Color', 'w');
theme(fig, 'light');
tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
nexttile
semilogx(fn, 20*log10(abs(H_21_ref)), 'k.-', 'LineWidth', 1.2)
grid on; xlim([20 45e3]); ylim([-0.05 0.2])
ylabel('|H_{21,ref}| [dB]')
title('Part 1: NI card + Nexus, measured on their own')
nexttile
semilogx(fn, angle(H_21_ref)*180/pi, 'k.-', 'LineWidth', 1.2)
grid on; xlim([20 45e3])
ylabel('phase [deg]'); xlabel('Frequency [Hz]')
exportgraphics(fig, fullfile(figdir, 'labC_part1_system_reference.png'), 'Resolution', 200);

%% The two numbers Part 2 needs
% The brief says to write down H_21_ref at 250 Hz and 1 kHz and to divide the
% calibration result by their *magnitude*, abs(H_21_250), which is a plain number
% close to 1:

H_ref_250  = abs(H_21_ref(fn == 250))
H_ref_1000 = abs(H_21_ref(fn == 1000))

%%
% On the lab PC the *dB* values were typed in instead (part2.m):

typed_250  = raw1.H_21_250
typed_1000 = raw1.H_21_1000

%%
% They are the same numbers in dB, as a check shows:

check_dB_250  = 20*log10(H_ref_250)
check_dB_1000 = 20*log10(H_ref_1000)

%%
% So every sensitivity in Part 2 was divided by 0.0036 instead of by 0.9996,
% which makes it about 277 times too large. Part 2 undoes this.

save(fullfile(outdir, 'part1_results.mat'), 'fn', 'use', 'H_21_ref', 'H_ref_250', 'H_ref_1000', 'typed_250', 'typed_1000');
