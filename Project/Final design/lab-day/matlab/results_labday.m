function results_labday()
% RESULTS_LABDAY  Figures + numbers for the 10-Nov results write-up -> ../results_2026-11-10/
here = fileparts(mfilename('fullpath')); addpath(fullfile(here, '..', 'kit'));
set(groot, 'DefaultFigureVisible', 'off'); try, set(groot, 'DefaultFigureTheme', 'light'); catch, end
dd = fullfile(here, '..', 'data'); out = fullfile(here, '..', 'results_2026-11-10');
if ~exist(out, 'dir'), mkdir(out); end
L = @(f) load(fullfile(dd, [f '.mat']));
r1 = L('project_R1_split_0'); r2 = L('project_R2_units_0'); r3 = L('project_R3_flip_0');
r5 = L('project_R5_repeat_0'); t2 = L('project_R1_try2_0');
fn = r1.fn; sm = @(x) lab_smooth(fn, 20*log10(abs(x)));
mod = @(s) lab_model('chamber', s, 0, fn);
b = fn >= 150 & fn <= 15000;
fid = fopen(fullfile(out, 'numbers.txt'), 'w');
P = @(varargin) fprintf(fid, varargin{:});

% ---- 1. the system: measured vs model, + the proposed pad
all1 = r1.H(:,3); ma = mod('all');
offm = median(20*log10(abs(all1(b))) - ma(b));     % one level shift for every model curve
yA = sm(all1); yM = lab_smooth(fn, ma); yM = yM + median(yA(b) - yM(b));
mid = r2.H(:,1); tw = r2.H(:,2); woof = r2.H(:,3) - mid - tw;
T = readmatrix(fullfile(here, '..', 'model', 'pad_ratio.csv'), 'NumHeaderLines', 1);
G = interp1(T(:,1), T(:,14) + 1j*T(:,15), fn, 'linear', 'extrap');    % column pair 7 = 4.7/8.2
yN = sm(woof + mid + tw .* G);
ref = median(yA(b));
f1 = lightfig('Position', [0 0 1000 520]); hold on
fill([150 15000 15000 150], ref + [-2 -2 2 2], [0.92 0.97 0.92], 'EdgeColor', 'none', 'HandleVisibility', 'off');
semilogx(fn, yA, 'k', 'LineWidth', 1.8, 'DisplayName', 'measured, as built (R1, 1/6 oct)');
semilogx(fn, yM, 'r--', 'LineWidth', 1.2, 'DisplayName', 'model (vent plugged), level-matched');
semilogx(fn, yN, 'Color', [0 0.45 0.8], 'LineWidth', 1.4, 'DisplayName', 'prediction with Rp = 8.2 \Omega (from R2 data)');
set(gca, 'XScale', 'log'); grid on; xlim([50 20000]); ylim(ref + [-20 10]);
xlabel('frequency (Hz)'); ylabel('|p/V| (dB re 1 Pa/V)'); legend('Location', 'south');
title('System D on axis, 10 Nov (green band: \pm2 dB, 150 Hz-15 kHz)');
exportgraphics(f1, fullfile(out, 'fig_system.png'), 'Resolution', 150);
P('spread 150-15k (1/6 oct): measured %.1f dB, model %.1f dB, with Rp 8.2: %.1f dB\n', ...
    max(yA(b))-min(yA(b)), max(yM(b))-min(yM(b)), max(yN(b))-min(yN(b)));
P('rms re own median: measured %.2f dB, Rp 8.2: %.2f dB\n', std(yA(b)), std(yN(b)));

% ---- 2. the three channels and the units, each vs model (same level shift)
f2 = lightfig('Position', [0 0 1000 620]);
ax = subplot(2,1,1); hold on; c = lines(3); nm = {'woofer', 'midtw', 'all'}; lb = {'woofer only', 'mid + tweeter', 'all three'};
for k = 1:3
    semilogx(fn, sm(r1.H(:,k)), 'Color', c(k,:), 'LineWidth', 1.4, 'DisplayName', ['meas ' lb{k}]);
    semilogx(fn, lab_smooth(fn, mod(nm{k})) + offm, '--', 'Color', c(k,:), 'HandleVisibility', 'off');
end
set(ax, 'XScale', 'log'); grid on; xlim([50 20000]); ylim(ref + [-30 10]); legend('Location', 'southwest');
title('R1: the two MiniDSP channels and their sum (dashed = model, one common level shift)'); ylabel('dB re 1 Pa/V');
ax = subplot(2,1,2); hold on; nm = {'mid', 'tw', 'all'}; lb = {'midrange only', 'tweeter only', 'all three'};
for k = 1:3
    semilogx(fn, sm(r2.H(:,k)), 'Color', c(k,:), 'LineWidth', 1.4, 'DisplayName', ['meas ' lb{k}]);
    semilogx(fn, lab_smooth(fn, mod(nm{k})) + offm, '--', 'Color', c(k,:), 'HandleVisibility', 'off');
end
set(ax, 'XScale', 'log'); grid on; xlim([50 20000]); ylim(ref + [-30 10]); legend('Location', 'southwest');
title('R2: midrange and tweeter through the board (same level shift: the tweeter sits low)');
xlabel('frequency (Hz)'); ylabel('dB re 1 Pa/V');
exportgraphics(f2, fullfile(out, 'fig_channels.png'), 'Resolution', 150);
bm = fn >= 600 & fn <= 2500; bt = fn >= 5000 & fn <= 15000; bw = fn >= 100 & fn <= 250;
P('re the common shift: woofer %+.1f, mid %+.1f, tweeter %+.1f dB\n', lv(r1.H(:,1), mod('woofer'), bw, offm), ...
    lv(r2.H(:,1), mod('mid'), bm, offm), lv(r2.H(:,2), mod('tw'), bt, offm));

% ---- 3. trust: repeatability and the sum check
f3 = lightfig('Position', [0 0 1000 520]);
ax = subplot(2,1,1); hold on
semilogx(fn, sm(t2.H(:,3)), 'Color', [0.6 0.6 0.6], 'LineWidth', 1.2, 'DisplayName', 'R1 try 2 (Out 1 -4.5 dB)');
semilogx(fn, sm(r1.H(:,3)), 'k', 'LineWidth', 1.6, 'DisplayName', 'R1 15:17 (Out 1 -10.3 dB)');
semilogx(fn, sm(r2.H(:,3)), 'Color', c(1,:), 'DisplayName', 'R2 15:31');
semilogx(fn, sm(r3.H(:,1)), 'Color', c(2,:), 'DisplayName', 'R3 15:40');
semilogx(fn, sm(r5.H(:,3)), 'Color', c(3,:), 'DisplayName', 'R5 15:48');
set(ax, 'XScale', 'log'); grid on; xlim([50 20000]); legend('Location', 'southwest');
title('Every "all" measurement of the day'); ylabel('dB re 1 Pa/V');
ax = subplot(2,1,2); hold on
semilogx(fn, sm(r5.H(:,3)) - sm(r1.H(:,3)), 'k', 'LineWidth', 1.4, 'DisplayName', 'R5 - R1 (repeat, 31 min later)');
semilogx(fn, sm(r1.H(:,1) + r1.H(:,2)) - sm(r1.H(:,3)), 'Color', c(1,:), 'LineWidth', 1.2, 'DisplayName', '|woofer + mid/tw| - |all| (R1)');
set(ax, 'XScale', 'log'); grid on; xlim([50 20000]); ylim([-1.5 1.5]); legend('Location', 'south');
xlabel('frequency (Hz)'); ylabel('dB'); title('Repeatability and the sum check');
exportgraphics(f3, fullfile(out, 'fig_trust.png'), 'Resolution', 150);
d5 = sm(r5.H(:,3)) - sm(r1.H(:,3)); ds = sm(r1.H(:,1) + r1.H(:,2)) - sm(r1.H(:,3));
P('R5-R1: median %+.2f, worst %.2f dB; sum check worst %.2f dB (150-15k)\n', median(d5(b)), max(abs(d5(b))), max(abs(ds(b))));

% ---- 4. phase between the units in the same run
f4 = lightfig('Position', [0 0 1000 420]); hold on
near = @(a, z) abs(20*log10(abs(a)) - 20*log10(abs(z))) < 10;
p1 = angle(woof ./ (mid + tw)) * 180/pi; p1(~near(woof, mid + tw) | fn > 1000) = NaN;
p2 = angle(mid ./ tw) * 180/pi; p2(~near(mid, tw) | fn < 1000) = NaN;
semilogx(fn, p1, 'LineWidth', 1.5, 'DisplayName', 'woofer - (mid+tw), around 325 Hz');
semilogx(fn, p2, 'LineWidth', 1.5, 'DisplayName', 'midrange - tweeter, around 3.8 kHz');
yline(0, ':k', 'HandleVisibility', 'off'); set(gca, 'XScale', 'log'); grid on; xlim([100 10000]); ylim([-180 180]);
xlabel('frequency (Hz)'); ylabel('phase difference (deg)'); legend('Location', 'southwest');
title('Phase between neighbouring units where their levels are within 10 dB (R2, one clock)');
exportgraphics(f4, fullfile(out, 'fig_phase.png'), 'Resolution', 150);

% ---- 5. flips: copy the dashboard's, near field: own
nf = {L('zinf_nf_cone_L200'), L('zinf_nf_vent_L200')};
f5 = lightfig('Position', [0 0 1000 420]); hold on
for k = 1:2
    w = {'cone', 'vent'};
    semilogx(nf{k}.fn, 20*log10(abs(nf{k}.H)), 'Color', c(k,:), 'LineWidth', 1.5, 'DisplayName', ['10 Nov ' w{k}]);
    semilogx(nf{k}.fn, lab_model('nf', w{k}, 200, nf{k}.fn), '--', 'Color', c(k,:), 'DisplayName', ['Lab D ' w{k}]);
end
set(gca, 'XScale', 'log'); grid on; xlim([5 1000]); ylim([-30 20]); legend('Location', 'southwest');
xlabel('frequency (Hz)'); ylabel('|p/V| (dB re 1 Pa/V)'); title('Near field, one vent at 200 mm: 10 Nov vs Lab D');
exportgraphics(f5, fullfile(out, 'fig_nearfield.png'), 'Resolution', 150);
copyfile(fullfile(dd, '2026-11-10', 'figures', 'Flips.png'), fullfile(out, 'fig_flips.png'));
fclose(fid); type(fullfile(out, 'numbers.txt'));
close all
end

function v = lv(H, ym, bb, offm)
v = median(20*log10(abs(H(bb))) - ym(bb)) - offm;
end

function f = lightfig(varargin)
f = figure(varargin{:}, 'Color', 'w');
try, f.Theme = 'light'; catch, end
end
