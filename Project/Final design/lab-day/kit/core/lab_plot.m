function two = lab_plot(kind, a1, a2, arg, pal)
% LAB_PLOT  The kit's graphs, drawn into given axes (uiaxes in labgui, axes in lab_dash).
%
%   two = lab_plot('run',     a1, a2, m)     one run: measured (solid) vs expected (dashed,
%                                            shifted by the fitted level), difference in a2
%   two = lab_plot('all',     a1, a2, runs)  every 'all' state of the day overlaid (drift)
%   two = lab_plot('phase',   a1, a2, runs)  woofer - mid/tw phase, latest run with S1 + S2
%   two = lab_plot('zboard',  a1, a2, runs)  Z1-Z3 (latest of each) vs the model
%   two = lab_plot('zwoofer', a1, a2, runs)  Z4 vs Lab D at the same vent length
%   two = lab_plot('nf',      a1, a2, runs)  N1, N2 vs Lab D
%   two = true when a2 was used (else the caller can hide it).
%   pal = gui_palette('light') (default; reports and the dashboard) or gui_palette('dark').

if nargin < 5 || isempty(pal), pal = gui_palette('light'); end
prep(a1); if ~isempty(a2), prep(a2); end
set(a1, 'ColorOrder', pal.lines);
two = false;
switch kind
case 'run'
    m = arg;
    if strcmp(m.station, 'chamber'), chamber_run(a1, a2, m, pal); two = true;
    else, zinf_run(a1, m, pal);
    end
case 'all'
    all_runs(a1, arg, pal);
case 'phase'
    phase(a1, arg, pal);
case 'zboard'
    zboard(a1, arg, pal);
case 'zwoofer'
    zwoofer(a1, arg, pal);
case 'nf'
    nfield(a1, arg, pal);
end
paint(a1, pal); if ~isempty(a2), paint(a2, pal); end
end

% =====================================================================
function chamber_run(a1, a2, m, pal)
P = lab_plan(); fn = m.fn(:);
c = cols(pal, numel(m.ids)); vt = {}; ytop = -Inf;
for k = 1:numel(m.ids)
    s = P(strcmp({P.id}, m.ids{k})); r = m.R(strcmp({m.R.id}, s.id));
    y = 20*log10(abs(m.H(:,k)));
    ymod = lab_model('chamber', s.model, s.angle, fn);
    semilogx(a1, fn, y, 'Color', c(k,:), 'LineWidth', 1.4, 'DisplayName', sprintf('%s %s', s.id, s.title));
    semilogx(a1, fn, ymod + r.offset, '--', 'Color', c(k,:), 'LineWidth', 1, 'HandleVisibility', 'off');
    rr = lab_smooth(fn, y - ymod - r.offset); rr(fn < s.band(1) | fn > s.band(2)) = NaN;
    ytop = max([ytop; y(fn > 50)]);
    semilogx(a2, fn, rr, 'Color', c(k,:), 'LineWidth', 1.3);
    vt{end+1} = colored(pal, r.verdict, sprintf('%s %s', s.id, r.verdict)); %#ok<AGROW>
end
for e = m.R(ismember({m.R.id}, {'bal', 'sum', 'F1n', 'F2n'}))
    vt{end+1} = colored(pal, e.verdict, sprintf('%s %s', e.id, e.verdict)); %#ok<AGROW>
end
style(a1, [50 20000]); ylabel(a1, '|p/V| (dB re 1 Pa/V)');
legend(a1, 'Location', 'southwest', 'Interpreter', 'none');
if isfinite(ytop), ylim(a1, [ytop - 40, ytop + 5]); end
title(a1, {sprintf('%s   %s   (solid = measured, dashed = expected)', esc(m.file), hhmm(m.time)), strjoin(vt, '   ')}, ...
    'Interpreter', 'tex');
style(a2, [50 20000]); ylim(a2, [-6 6]);
yline(a2, [-1.5 1.5], ':', 'Color', pal.axfg, 'HandleVisibility', 'off'); yline(a2, 0, '-', 'Color', pal.grid*0.6 + pal.axbg*0.4, 'HandleVisibility', 'off');
ylabel(a2, {'measured - expected', '(dB, 1/6 oct, in band)'}); xlabel(a2, 'frequency (Hz)');
end

function zinf_run(a, m, pal)
P = lab_plan(); s = P(strcmp({P.id}, m.ids{1})); r = m.R(1);
if isfield(m, 'Z')
    loglog(a, m.fn, abs(m.Z), 'Color', pal.ink, 'LineWidth', 1.5, 'DisplayName', 'measured');
    if startsWith(s.model, 'board')
        Zm = lab_model('zinf', s.model, 0, m.fn);
        loglog(a, m.fn, 10.^(Zm/20), '--', 'Color', pal.model, 'LineWidth', 1.1, 'DisplayName', 'model');
        xlim(a, [20 24000]); ylim(a, [2 200]);
        yline(a, 4, ':', '4 \Omega', 'Color', pal.model, 'HandleVisibility', 'off');
    else
        [ref, ok] = lab_model('woofer', '', m.setup.vent_mm, []);
        if ok, loglog(a, ref.fn, abs(ref.Z), '--', 'Color', pal.model, 'LineWidth', 1.1, 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm)); end
        xlim(a, [5 500]);
    end
    set(a, 'XScale', 'log', 'YScale', 'log'); ylabel(a, '|Z| (\Omega)');
else
    semilogx(a, m.fn, 20*log10(abs(m.H)), 'Color', pal.ink, 'LineWidth', 1.5, 'DisplayName', 'measured');
    [ref, ok] = lab_model('nf', erase(s.model, 'nf_'), m.setup.vent_mm, m.fn);
    if ok, semilogx(a, m.fn, ref, '--', 'Color', pal.model, 'LineWidth', 1.1, 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm)); end
    set(a, 'XScale', 'log'); xlim(a, [5 2000]); ylabel(a, '|p/V| (dB re 1 Pa/V)');
end
grid(a, 'on'); box(a, 'on'); xlabel(a, 'frequency (Hz)'); legend(a, 'Location', 'best');
title(a, {sprintf('%s   %s', esc(m.file), hhmm(m.time)), colored(pal, r.verdict, sprintf('%s %s: %s', s.id, r.verdict, esc(s.title)))}, ...
    'Interpreter', 'tex');
end

function all_runs(a, runs, pal)
n = 0;
for i = 1:numel(runs)
    m = runs{i}; k = find(ismember(m.ids, {'S3', 'F0'}));
    if isempty(k) || ~strcmp(m.station, 'chamber'), continue; end
    semilogx(a, m.fn, lab_smooth(m.fn, 20*log10(abs(m.H(:,k(1))))), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('%s %s', m.file, hhmm(m.time)));
    n = n + 1;
end
style(a, [50 20000]); ylabel(a, 'dB re 1 Pa/V (1/6 oct)'); xlabel(a, 'frequency (Hz)');
title(a, sprintf('Every "all" state today (S3 / F0, 0 deg): %d. They should lie on top of each other.', n));
if n, legend(a, 'Location', 'southwest', 'Interpreter', 'none'); else, nothing(a, pal, 'No run with S3 or F0 yet.'); end
end

function phase(a, runs, pal)
iS = find(cellfun(@(m) all(ismember({'S1', 'S2'}, m.ids)), runs), 1, 'last');
if isempty(iS), nothing(a, pal, 'Measure the run S (S1, S2, S3 in one go) to see the phase between the channels.'); return; end
m = runs{iS}; w = m.H(:, strcmp(m.ids, 'S1')); t = m.H(:, strcmp(m.ids, 'S2'));
near = abs(20*log10(abs(w)) - 20*log10(abs(t))) < 15;
ph = angle(w ./ t) * 180/pi; ph(~near) = NaN;
semilogx(a, m.fn, ph, 'Color', pal.ink, 'LineWidth', 1.4);
yline(a, 0, ':', 'Color', pal.axfg); style(a, [100 2000]); ylim(a, [-180 180]);
title(a, sprintf('woofer - mid/tw phase, run %s (about 0 deg near 325 Hz = in phase)', m.file), 'Interpreter', 'none');
ylabel(a, 'phase difference (deg)'); xlabel(a, 'frequency (Hz)');
end

function zboard(a, runs, pal)
P = lab_plan(); ids = {'Z1', 'Z2', 'Z3'}; c = cols(pal, 3); vt = {}; n = 0;
for j = 1:3
    [m, r] = latest(runs, ids{j});
    if isempty(m), continue; end
    s = P(strcmp({P.id}, ids{j}));
    loglog(a, m.fn, abs(m.Z), 'Color', c(j,:), 'LineWidth', 1.4, 'DisplayName', [s.id ' ' s.title]);
    Zm = lab_model('zinf', s.model, 0, m.fn);
    loglog(a, m.fn, 10.^(Zm/20), '--', 'Color', c(j,:), 'HandleVisibility', 'off');
    vt{end+1} = colored(pal, r.verdict, sprintf('%s %s', s.id, r.verdict)); %#ok<AGROW>
    n = n + 1;
end
if ~n, nothing(a, pal, 'No board impedance (Z1-Z3) measured yet.'); return; end
set(a, 'XScale', 'log', 'YScale', 'log'); grid(a, 'on'); box(a, 'on'); xlim(a, [20 24000]); ylim(a, [2 200]);
yline(a, 4, ':', '4 \Omega', 'Color', pal.model, 'HandleVisibility', 'off');
ylabel(a, '|Z| (\Omega)'); xlabel(a, 'frequency (Hz)'); legend(a, 'Location', 'northwest');
title(a, {'Board input: measured (solid) vs model (dashed)', strjoin(vt, '   ')}, 'Interpreter', 'tex');
end

function zwoofer(a, runs, pal)
[m, r] = latest(runs, 'Z4');
if isempty(m), nothing(a, pal, 'Z4 (woofer in the box) not measured yet.'); return; end
semilogx(a, m.fn, abs(m.Z), 'Color', pal.ink, 'LineWidth', 1.4, 'DisplayName', 'today');
[ref, ok] = lab_model('woofer', '', m.setup.vent_mm, []);
if ok, semilogx(a, ref.fn, abs(ref.Z), '--', 'Color', pal.model, 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm)); end
set(a, 'XScale', 'log'); grid(a, 'on'); box(a, 'on'); xlim(a, [5 500]); legend(a);
title(a, {colored(pal, r.verdict, sprintf('Z4 woofer in the box: %s', r.verdict)), esc(r.msg)}, 'Interpreter', 'tex');
ylabel(a, '|Z| (\Omega)'); xlabel(a, 'frequency (Hz)');
end

function nfield(a, runs, pal)
P = lab_plan(); ids = {'N1', 'N2'}; c = cols(pal, 2); vt = {}; n = 0;
for j = 1:2
    [m, r] = latest(runs, ids{j});
    if isempty(m), continue; end
    s = P(strcmp({P.id}, ids{j}));
    semilogx(a, m.fn, 20*log10(abs(m.H)), 'Color', c(j,:), 'LineWidth', 1.4, 'DisplayName', [s.id ' ' s.title]);
    [ref, ok] = lab_model('nf', erase(s.model, 'nf_'), m.setup.vent_mm, m.fn);
    if ok, semilogx(a, m.fn, ref, '--', 'Color', c(j,:), 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm)); end
    vt{end+1} = colored(pal, r.verdict, sprintf('%s %s', s.id, r.verdict)); %#ok<AGROW>
    n = n + 1;
end
if ~n, nothing(a, pal, 'No near field (N1, N2) measured yet.'); return; end
set(a, 'XScale', 'log'); grid(a, 'on'); box(a, 'on'); xlim(a, [5 2000]);
ylabel(a, '|p/V| (dB re 1 Pa/V)'); xlabel(a, 'frequency (Hz)'); legend(a, 'Location', 'southwest');
title(a, {'Near field: today (solid) vs Lab D (dashed)', strjoin(vt, '   ')}, 'Interpreter', 'tex');
end

% ---------------------------------------------------------------------
function [m, r] = latest(runs, id)
m = []; r = [];
for i = numel(runs):-1:1
    if any(strcmp(runs{i}.ids, id))
        m = runs{i}; r = m.R(strcmp({m.R.id}, id)); return
    end
end
end

function prep(a)
legend(a, 'off'); cla(a, 'reset'); hold(a, 'on');
try, a.Toolbar.Visible = 'off'; catch, end
end

function nothing(a, pal, txt)
set(a, 'XScale', 'linear', 'YScale', 'linear'); xlim(a, [0 1]); ylim(a, [0 1]);
text(a, 0.5, 0.5, txt, 'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', pal.muted);
a.XTick = []; a.YTick = []; box(a, 'on');
end

function style(a, xl)
set(a, 'XScale', 'log'); grid(a, 'on'); grid(a, 'minor'); xlim(a, xl); box(a, 'on');
end

function s = colored(pal, v, txt)
if isfield(pal.vtext, v), c = pal.vtext.(v); else, c = pal.muted; end
s = sprintf('\\color[rgb]{%g,%g,%g}%s', c, txt);
end

function c = cols(pal, n)
c = pal.lines(mod(0:max(n, 1) - 1, size(pal.lines, 1)) + 1, :);
end

function paint(a, pal)
% the palette's axes colours (also for uiaxes on MATLAB without themes)
set(a, 'Color', pal.axbg, 'XColor', pal.axfg, 'YColor', pal.axfg, 'GridColor', pal.grid, 'MinorGridColor', pal.grid);
try, a.Title.Color = pal.fg; catch, end
try
    lg = a.Legend;
    if ~isempty(lg), set(lg, 'Color', pal.axbg, 'TextColor', pal.fg, 'EdgeColor', pal.grid*0.5 + pal.axbg*0.5); end
catch
end
end

function s = esc(s)
s = strrep(char(s), '_', '\_');
end

function s = hhmm(t)
s = char(datetime(t, 'Format', 'HH:mm'));
end
