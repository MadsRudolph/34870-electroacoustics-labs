function results_1112()
% RESULTS_1112  Figures + numbers for the 12-Nov anechoic runs -> ../results_2026-11-12/
%   Usable runs: P (placement), S_3 (Rp 8.2), S_4 (Rp 3.3), S_5 (Out 1 changed).
%   S and S_2 had the amplifier channels swapped. All S runs had the Out 2 high-pass applied
%   twice; the "corrected" curves divide that second LR4 (two MiniDSP biquads) out of the
%   mid/tweeter state and add the woofer of the SAME run (one clock, so the phases add).

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'kit', 'core')); L = labpaths();
set(groot, 'DefaultFigureVisible', 'off');
out = fullfile(L.root, 'results_2026-11-12'); if ~exist(out, 'dir'), mkdir(out); end
d12 = fullfile(L.data, '2026-11-12'); d10 = fullfile(L.data, '2026-11-10');
r10 = load(fullfile(d10, 'S.mat')); fn = r10.fn;
db = @(x) 20*log10(abs(x)); sm = @(x) lab_smooth(fn, db(x));
H = @(m, k) interp1(m.fn, m.H(:,k), fn);
c = [0.985071534815898 -1.970143069631796 0.985071534815898 1.969920198141118 -0.970365941122475];
z1 = exp(-1j*2*pi*fn/96000);
BQ = (c(1) + c(2)*z1 + c(3)*z1.^2) ./ (1 - c(4)*z1 - c(5)*z1.^2);   % one MiniDSP HP biquad (BW2)
BQ2 = BQ.^2; BQ2(fn < 150) = 1;   % undo the extra LR4 only where mid/tw is above the noise
s3 = load(fullfile(d12, 'S_3.mat')); s4 = load(fullfile(d12, 'S_4.mat')); P = load(fullfile(d12, 'P.mat'));
k = fn >= 150 & fn <= 15000;
fid = fopen(fullfile(out, 'numbers.txt'), 'w'); W = @(varargin) fprintf(fid, varargin{:});
col = lines(4);

% 1. the system: 10-Nov, 12-Nov as measured, 12-Nov with the doubled filter removed
w3 = H(s3,1); t3 = H(s3,2); a3 = sm(w3 + t3); c3 = sm(w3 + t3 ./ BQ2); a10 = sm(r10.H(:,3));
ref = median(a10(k)); a3 = a3 - median(a3(k)) + ref; c3 = c3 - median(c3(k)) + ref;
f = lightfig([0 0 1000 520]); hold on
fill([150 15000 15000 150], ref + [-2 -2 2 2], [0.92 0.97 0.92], 'EdgeColor', 'none', 'HandleVisibility', 'off');
semilogx(fn, a10, 'Color', [0.55 0.55 0.55], 'LineWidth', 1.3, 'DisplayName', '10 Nov (Rp 3.3, Out 2 correct)');
semilogx(fn, a3, 'r', 'LineWidth', 1.3, 'DisplayName', '12 Nov S\_3 as measured (Out 2 high-pass applied twice)');
semilogx(fn, c3, 'k', 'LineWidth', 1.8, 'DisplayName', '12 Nov S\_3 with the extra high-pass removed (Rp 8.2)');
set(gca, 'XScale', 'log'); grid on; xlim([50 20000]); ylim(ref + [-22 8]);
xlabel('frequency (Hz)'); ylabel('|p/V| (dB, 1/6 oct, level-matched)'); legend('Location', 'south');
title('System D on axis (green: \pm2 dB, 150 Hz-15 kHz)');
save_png(f, fullfile(out, 'fig_system.png'), 150);
sp = @(x) max(x(k)) - min(x(k));
W('spread 150-15k / rms: 10-Nov %.1f / %.2f dB; S_3 measured %.1f / %.2f; S_3 corrected %.1f / %.2f\n', ...
    sp(a10), std(a10(k)), sp(a3), std(a3(k)), sp(c3), std(c3(k)));
c4 = sm(H(s4,1) + H(s4,2) ./ BQ2);
W('S_4 (Rp 3.3) corrected: %.1f / %.2f dB\n', sp(c4), std(c4(k)));

% 2. proof: today's mid/tw divided by 10-Nov's against 1, 2, 3 extra biquads
ratio = db(H(s3,2) ./ r10.H(:,2)); b = fn >= 170 & fn <= 1000;
f = lightfig([0 0 1000 420]); hold on
semilogx(fn, ratio - median(ratio(fn > 800 & fn < 1200)), 'k', 'LineWidth', 1.6, 'DisplayName', 'S\_3 mid+tw / 10-Nov mid+tw');
for n = 1:3
    e = ratio(b) - n*db(BQ(b)); e = e - median(e);
    semilogx(fn, n*db(BQ), '--', 'Color', col(n,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%d extra MiniDSP HP section(s): misfit %.1f dB rms', n, sqrt(mean(e.^2))));
end
set(gca, 'XScale', 'log'); grid on; xlim([100 2000]); ylim([-35 5]); legend('Location', 'southeast');
xlabel('frequency (Hz)'); ylabel('dB'); title('What changed in the mid/tweeter channel: exactly one extra LR4 high-pass (2 sections)');
save_png(f, fullfile(out, 'fig_double_filter.png'), 150);

% 3. phase between the channels (same run)
near = @(a, z) abs(db(a) - db(z)) < 10;
ph = @(a, z) angle(a ./ z) * 180/pi;
f = lightfig([0 0 1000 400]); hold on
p10 = ph(r10.H(:,1), r10.H(:,2)); p10(~near(r10.H(:,1), r10.H(:,2))) = NaN;
p3 = ph(w3, t3); p3(~near(w3, t3)) = NaN;
pc = ph(w3, t3 ./ BQ2); pc(~near(w3, t3 ./ BQ2)) = NaN;
semilogx(fn, p10, 'Color', [0.55 0.55 0.55], 'LineWidth', 1.3, 'DisplayName', '10 Nov');
semilogx(fn, p3, 'r', 'LineWidth', 1.3, 'DisplayName', '12 Nov S\_3 as measured');
semilogx(fn, pc, 'k', 'LineWidth', 1.6, 'DisplayName', '12 Nov S\_3, extra high-pass removed');
yline(0, ':'); set(gca, 'XScale', 'log'); grid on; xlim([150 800]); ylim([-180 180]);
xlabel('frequency (Hz)'); ylabel('woofer - mid/tw (deg)'); legend('Location', 'southwest');
title('Phase between woofer and mid/tweeter where their levels are within 10 dB (one run each)');
save_png(f, fullfile(out, 'fig_phase.png'), 150);

% 4. Rp 8.2 vs 3.3 (same day, same chain: S_3 vs S_4)
d = db(H(s3,2)) - db(H(s4,2));
f = lightfig([0 0 1000 380]); semilogx(fn, lab_smooth(fn, d), 'k', 'LineWidth', 1.6); hold on
T = readmatrix(fullfile(L.model, 'pad_ratio.csv'), 'NumHeaderLines', 1);
G = interp1(T(:,1), T(:,14) + 1j*T(:,15), fn, 'linear', 'extrap');
u = load(fullfile(d10, 'S4+S5+S3.mat')); um = interp1(u.fn, u.H(:,1), fn); ut = interp1(u.fn, u.H(:,2), fn);
semilogx(fn, lab_smooth(fn, db((um + ut .* G) ./ (um + ut))), 'r--', 'LineWidth', 1.2);   % mid + tw, 10-Nov units
set(gca, 'XScale', 'log'); grid on; xlim([500 20000]); ylim([-2 6]);
legend('measured: S\_3 (Rp 8.2) - S\_4 (Rp 3.3), mid+tw', 'predicted (10-Nov mid + tweeter, board model)', 'Location', 'northwest');
xlabel('frequency (Hz)'); ylabel('dB'); title('The tweeter fix: Rp 3.3 \rightarrow 8.2 \Omega');
save_png(f, fullfile(out, 'fig_rp.png'), 150);
W('Rp 8.2 - 3.3: 5-15 kHz %+.1f dB, 1-3 kHz %+.1f dB\n', median(d(fn >= 5000 & fn <= 15000)), median(d(fn >= 1000 & fn <= 3000)));

% 5. placement: P against the bare Lab E units
f = lightfig([0 0 1000 420]); hold on; nm = {'woofer', 'mid', 'tw'}; lb = {'woofer', 'midrange', 'tweeter'};
for j = 1:3
    y = db(P.H(:,j)); ym = lab_model('chamber', ['dir_' nm{j}], 0, P.fn);
    bb = ~isnan(ym) & P.fn > 150; off = median(y(bb) - ym(bb));
    semilogx(P.fn, lab_smooth(P.fn, y), 'Color', col(j,:), 'LineWidth', 1.4, 'DisplayName', ['P: ' lb{j}]);
    semilogx(P.fn, lab_smooth(P.fn, ym) + off, '--', 'Color', col(j,:), 'HandleVisibility', 'off');
    r = lab_smooth(P.fn, y - ym - off); W('P%d vs Lab E %s: level %+.1f dB, shape %.1f dB rms\n', j, lb{j}, off, sqrt(mean(r(bb).^2, 'omitnan')));
end
set(gca, 'XScale', 'log'); grid on; xlim([50 20000]); ylim([-30 25]); legend('Location', 'southwest');
xlabel('frequency (Hz)'); ylabel('|p/V| (dB, 1/6 oct)'); title('Placement check P vs Lab E (dashed), MiniDSP bypassed: the units were not behind the board');
save_png(f, fullfile(out, 'fig_placement.png'), 150);
fclose(fid); type(fullfile(out, 'numbers.txt')); close all
end

function f = lightfig(pos)
f = figure('Position', pos, 'Color', 'w');
try, f.Theme = 'light'; catch, end
end
