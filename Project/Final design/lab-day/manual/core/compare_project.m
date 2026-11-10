function r = compare_project(m)
% COMPARE_PROJECT  Measured run vs. the model, level-matched, with the checks for the day.
%
%   r = compare_project(m)          m = struct from measure_project, or a file name
%
% Model curves: lab-day/model/expected_on.csv (0 deg) and expected_off30.csv (30 deg),
% written by `python3 model_curves.py` (vent plugged, as in the chamber).
%
% The amplifier volume and the MiniDSP shift the whole level, so one offset is
% fitted per state (median of measured - model where that state is loud) and
% printed. What to look at:
%   * offsets of 'woofer' and 'midtw' should agree within ~1 dB. A larger gap
%     means the two amplifier channels (or the Out 1 gain) are not what the
%     model assumes: fix it with the Out 1 gain in the MiniDSP, not the board.
%   * shape error after the offset, 150 Hz - 15 kHz (1/6 oct smoothed).
%   * if the run holds 'woofer', 'midtw' and 'all': |H_woofer + H_midtw| must
%     equal |H_all| (same run, so the phases add). A mismatch means something
%     moved or changed between the states.
%   * flipW / flipT: the notch frequency and depth (the model says ~329 Hz,
%     -21 dB and ~3.9 kHz, -14 dB re the normal sum).

if ischar(m) || isstring(m), m = load(m); end
L = labpaths();
switch m.angle_deg
    case 0,  csvf = fullfile(L.model, 'expected_on.csv');
    case 30, csvf = fullfile(L.model, 'expected_off30.csv');
    otherwise, csvf = '';
end
r = struct('tag', m.tag, 'states', {m.states}, 'offset_dB', nan(1, numel(m.states)), ...
    'shape_rms_dB', nan(1, numel(m.states)));
fn = m.fn(:);
Hm = m.H;
have = ~isempty(csvf) && exist(csvf, 'file');
if have
    T = readmatrix(csvf, 'NumHeaderLines', 1);
    hdr = strsplit(strtrim(fgetl_first(csvf)), ',');
    fmod = T(:,1);
end
loud = struct('woofer', [100 250], 'midtw', [600 15000], 'mid', [600 2500], ...
    'tw', [5000 15000], 'all', [150 15000], 'flipW', [1000 15000], 'flipT', [150 1500]);

figure('Name', ['compare ' m.tag]);
cols = lines(numel(m.states));
for k = 1:numel(m.states)
    s = m.states{k};
    ym = 20*log10(abs(Hm(:,k)));
    semilogx(fn, ym, 'Color', cols(k,:), 'LineWidth', 1.3, 'DisplayName', ['meas ' s]); hold on
    if have
        ire = find(strcmp(hdr, [s '_re'])); iim = find(strcmp(hdr, [s '_im']));
        Hmod = T(:,ire) + 1j*T(:,iim);
        ymod = interp1(log(fmod), 20*log10(abs(Hmod)), log(fn), 'linear', NaN);
        b = loud.(s); kk = fn >= b(1) & fn <= b(2) & ~isnan(ymod);
        off = median(ym(kk) - ymod(kk));
        sh = sm6(fn, ym - ymod - off);
        k2 = fn >= 150 & fn <= 15000 & ~isnan(sh);
        if any(strcmp(s, {'woofer', 'mid', 'tw'})), k2 = kk; end
        r.offset_dB(k) = off;
        r.shape_rms_dB(k) = sqrt(mean(sh(k2).^2));
        semilogx(fn, ymod + off, '--', 'Color', cols(k,:), 'LineWidth', 1, ...
            'DisplayName', sprintf('model %s %+.1f dB', s, off));
    end
end
grid on; xlim([50 20000]); xlabel('frequency (Hz)'); ylabel('|p/V| (dB re 1 Pa/V)');
title(sprintf('%s, %g deg (dashed: model shifted by the fitted offset)', m.tag, m.angle_deg), ...
    'Interpreter', 'none');
legend('Location', 'southwest', 'Interpreter', 'none'); hold off
yl = ylim; ylim([max(yl(1), yl(2) - 60) yl(2)]);

fprintf('\n%s  (%g deg)\n', m.tag, m.angle_deg);
for k = 1:numel(m.states)
    fprintf('  %-7s level offset vs model %+6.1f dB, shape error (rms, 1/6 oct) %.1f dB\n', ...
        m.states{k}, r.offset_dB(k), r.shape_rms_dB(k));
end
iw = find(strcmp(m.states, 'woofer')); it = find(strcmp(m.states, 'midtw'));
ia = find(strcmp(m.states, 'all'));
if ~isempty(iw) && ~isempty(it)
    r.channel_gap_dB = r.offset_dB(iw) - r.offset_dB(it);
    fprintf('  woofer - midtw offset: %+.1f dB (want within +-1 dB; else adjust the Out 1 gain by %+.1f dB)\n', ...
        r.channel_gap_dB, -r.channel_gap_dB);
end
if ~isempty(iw) && ~isempty(it) && ~isempty(ia)
    d = 20*log10(abs(Hm(:,iw) + Hm(:,it))) - 20*log10(abs(Hm(:,ia)));
    kk = fn >= 150 & fn <= 15000;
    ds = sm6(fn, d);
    r.sum_check_dB = max(abs(ds(kk)), [], 'omitnan');
    fprintf('  sum check |woofer+midtw| vs |all|: worst %.2f dB (1/6 oct, 150 Hz-15 kHz)\n', ...
        r.sum_check_dB);
end
for s = {'flipW', 'flipT'}
    i = find(strcmp(m.states, s{1}));
    if isempty(i) || isempty(ia), continue; end
    if strcmp(s{1}, 'flipW'), b = [200 600]; else, b = [2000 6000]; end
    kk = find(fn >= b(1) & fn <= b(2));
    d = 20*log10(abs(Hm(kk,i))) - 20*log10(abs(Hm(kk,ia)));
    [dmin, j] = min(d);
    fprintf('  %s: notch %.0f Hz, %.1f dB below the normal sum\n', s{1}, fn(kk(j)), dmin);
    r.([s{1} '_notch']) = [fn(kk(j)) dmin];
end
end

function y = sm6(f, x)
% 1/6-octave smoothing on the measurement grid (NaN-safe)
lf = log2(f); y = nan(size(x));
for i = 1:numel(f)
    k = abs(lf - lf(i)) <= 1/12;
    y(i) = mean(x(k), 'omitnan');
end
end

function l = fgetl_first(file)
fid = fopen(file); l = fgetl(fid); fclose(fid);
end
