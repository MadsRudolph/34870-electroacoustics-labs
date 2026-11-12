function lab_view(kind, ax, C, varargin)
% LAB_VIEW  Draw one of the GUI's plots into the given axes (uiaxes or axes).
%
%   lab_view('run',     [a1 a2],       C, m)      one run: measured (solid) vs expected (dashed,
%                                                 level-matched), the difference underneath
%   lab_view('overlay', [a1 a2],       C, runs)   every "all" run of the day + difference to the first
%   lab_view('z',       [a1 a2 a3 a4], C, runs)   impedance: board |Z| + phase, woofer |Z| + phase
%   lab_view('nf',      [a1 a2],       C, runs)   near field: level + phase, vs Lab D
%   lab_view('empty',   ax,            C, msg)    blank axes with a message
%
%   C = lab_palette('light' | 'dark'). m / runs{i} are judged runs (lab_judge / lab_runs).

for a = ax(:)', cla(a, 'reset'); hold(a, 'on'); end
switch kind
    case 'run'
        m = varargin{1};
        if strcmp(m.station, 'chamber'), run_chamber(ax, C, m);
        elseif isfield(m, 'Z'), run_z(ax, C, m);
        else, run_nf(ax, C, m);
        end
    case 'overlay', overlay(ax, C, varargin{1});
    case 'z',       z_all(ax, C, varargin{1});
    case 'nf',      nf_all(ax, C, varargin{1});
    case 'empty',   for a = ax(:)', blank(a, C, varargin{1}); end
end
end

% =====================================================================
function run_chamber(ax, C, m)
P = lab_plan(); fn = m.fn(:); a1 = ax(1); a2 = ax(2);
vt = {}; ytop = -Inf;
for k = 1:numel(m.ids)
    s = P(strcmp({P.id}, m.ids{k})); c = col(C, k);
    y = 20*log10(abs(m.H(:,k)));
    [ymod, okm] = lab_model('chamber', s.model, s.angle, fn);
    r = m.R(strcmp({m.R.id}, s.id));
    if isempty(r), b = fn >= s.band(1) & fn <= s.band(2) & okm; off = median(y(b) - ymod(b)); v = '';
    else, off = r(1).offset; v = r(1).verdict; end
    semilogx(a1, fn, y, 'Color', c, 'LineWidth', 1.4, 'DisplayName', sprintf('%s %s', s.id, s.title));
    semilogx(a1, fn, ymod + off, '--', 'Color', c, 'LineWidth', 1, 'HandleVisibility', 'off');
    rr = lab_smooth(fn, y - ymod - off); rr(fn < s.band(1) | fn > s.band(2)) = NaN;
    semilogx(a2, fn, rr, 'Color', c, 'LineWidth', 1.4);
    ytop = max([ytop; y(fn > 50)]);
    vt{end+1} = chip(C, s.id, v); %#ok<AGROW>
end
for e = m.R(ismember({m.R.id}, {'bal', 'sum', 'F1n', 'F2n'})), vt{end+1} = chip(C, e.id, e.verdict); end %#ok<AGROW>
style(a1, C, [50 20000]); ylabel(a1, '|p/V| (dB re 1 Pa/V)');
if isfinite(ytop), ylim(a1, [ytop - 40, ytop + 5]); end
title(a1, {head(m, 'measured (solid) vs expected (dashed, level-matched)'), strjoin(vt, '   ')}, 'Interpreter', 'tex', 'Color', C.axfg);
leg(a1, C, 'southwest');
style(a2, C, [50 20000]); ylim(a2, [-6 6]);
yline(a2, 1.5, ':', 'Color', C.model, 'HandleVisibility', 'off'); yline(a2, -1.5, ':', 'Color', C.model, 'HandleVisibility', 'off');
ylabel(a2, 'measured - expected (dB)'); xlabel(a2, 'frequency (Hz)');
title(a2, 'difference, 1/6 octave, inside each step''s band (dotted: +-1.5 dB)', 'FontWeight', 'normal', 'Color', C.axfg);
end

function run_z(ax, C, m)
P = lab_plan(); s = P(strcmp({P.id}, m.ids{1})); fn = m.fn(:); a1 = ax(1); a2 = ax(2);
v = ''; if ~isempty(m.R), v = m.R(1).verdict; end
loglog(a1, fn, abs(m.Z), 'Color', col(C, 1), 'LineWidth', 1.5, 'DisplayName', 'measured');
semilogx(a2, fn, angle(m.Z)*180/pi, 'Color', col(C, 1), 'LineWidth', 1.5);
if startsWith(s.model, 'board')
    M = lab_model('zinf_raw', s.model, 0);
    loglog(a1, M.f, abs(M.H), '--', 'Color', C.model, 'DisplayName', 'model');
    semilogx(a2, M.f, angle(M.H)*180/pi, '--', 'Color', C.model);
    yline(a1, 4, ':', 'Color', C.bad, 'HandleVisibility', 'off');
    xl = [20 24000]; yl = [2 200];
else
    [ref, ok] = lab_model('woofer', '', m.setup.vent_mm, []);
    if ok
        loglog(a1, ref.fn, abs(ref.Z), '--', 'Color', C.model, 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm));
        semilogx(a2, ref.fn, angle(ref.Z)*180/pi, '--', 'Color', C.model);
    end
    xl = [5 500]; yl = [1 200];
end
style(a1, C, xl); set(a1, 'YScale', 'log'); ylim(a1, yl); ylabel(a1, '|Z| (ohm)');
title(a1, {head(m, 'measured (solid) vs reference (dashed)'), chip(C, s.id, v)}, 'Interpreter', 'tex', 'Color', C.axfg);
leg(a1, C, 'northwest');
style(a2, C, xl); ylim(a2, [-90 90]); ylabel(a2, 'phase of Z (deg)'); xlabel(a2, 'frequency (Hz)');
yline(a2, 0, ':', 'Color', C.model);
end

function run_nf(ax, C, m)
P = lab_plan(); s = P(strcmp({P.id}, m.ids{1})); fn = m.fn(:); a1 = ax(1); a2 = ax(2);
v = ''; if ~isempty(m.R), v = m.R(1).verdict; end
y = 20*log10(abs(m.H(:)));
semilogx(a1, fn, y, 'Color', col(C, 1), 'LineWidth', 1.5, 'DisplayName', 'measured');
[ref, ok] = lab_model('nf', erase(s.model, 'nf_'), m.setup.vent_mm, fn);
if ok
    semilogx(a1, fn, ref, '--', 'Color', C.model, 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm));
    b = fn >= s.band(1) & fn <= s.band(2); d = y - ref; d = d - median(d(b), 'omitnan'); d(~b) = NaN;
    semilogx(a2, fn, d, 'Color', col(C, 1), 'LineWidth', 1.5);
    yline(a2, 1, ':', 'Color', C.model); yline(a2, -1, ':', 'Color', C.model);
end
style(a1, C, [5 2000]); ylabel(a1, '|p/V| (dB re 1 Pa/V)');
title(a1, {head(m, 'measured (solid) vs Lab D (dashed)'), chip(C, s.id, v)}, 'Interpreter', 'tex', 'Color', C.axfg);
leg(a1, C, 'southwest');
style(a2, C, [5 2000]); ylim(a2, [-6 6]); ylabel(a2, 'measured - Lab D (dB)'); xlabel(a2, 'frequency (Hz)');
title(a2, sprintf('difference after level-matching, %g-%g Hz (dotted: +-1 dB)', s.band), 'FontWeight', 'normal', 'Color', C.axfg);
end

function overlay(ax, C, runs)
a1 = ax(1); a2 = ax(2); n = 0; y0 = []; f0 = [];
for i = 1:numel(runs)
    m = runs{i};
    if ~strcmp(m.station, 'chamber'), continue; end
    k = find(ismember(m.ids, {'S3', 'F0', 'A3'}), 1);
    if isempty(k), continue; end
    n = n + 1; c = col(C, n); ls = '-'; tag = '';
    if m.angle == 30, ls = '--'; tag = ' (30 deg)'; end
    if isfield(m, 'manual') && m.manual, tag = [tag ' (manual)']; end %#ok<AGROW>
    y = lab_smooth(m.fn, 20*log10(abs(m.H(:,k))));
    semilogx(a1, m.fn, y, ls, 'Color', c, 'LineWidth', 1.3, ...
        'DisplayName', sprintf('%s  %s%s', char(datetime(m.time, 'Format', 'HH:mm')), m.file, tag));
    if isempty(y0) && m.angle == 0, y0 = y; f0 = m.fn; end
    if ~isempty(y0) && m.angle == 0 && numel(y) == numel(y0)
        semilogx(a2, m.fn, y - y0, 'Color', c, 'LineWidth', 1.3);
    end
end
if n == 0, blank(a1, C, {'No "all" run yet.', 'Measure S (or F): every "all" curve of the day is overlaid here.'}); blank(a2, C, ''); return; end
style(a1, C, [50 20000]); ylabel(a1, '|p/V| (dB re 1 Pa/V)');
title(a1, sprintf('Every "all" run of the day (%d), 1/6 octave: they should lie on top of each other', n), 'Color', C.axfg);
leg(a1, C, 'southwest');
style(a2, C, [50 20000]); ylim(a2, [-3 3]); ylabel(a2, 'run - first run (dB)'); xlabel(a2, 'frequency (Hz)');
yline(a2, 0.5, ':', 'Color', C.model); yline(a2, -0.5, ':', 'Color', C.model);
title(a2, 'difference to the first 0 deg run (dotted: +-0.5 dB)', 'FontWeight', 'normal', 'Color', C.axfg);
end

function z_all(ax, C, runs)
P = lab_plan(); L = latest(runs); ids = {'Z1', 'Z2', 'Z3'}; vt = {}; any1 = false;
for j = 1:3
    if ~isfield(L, ids{j}), continue; end
    m = L.(ids{j}); s = P(strcmp({P.id}, ids{j})); c = col(C, j); any1 = true;
    loglog(ax(1), m.fn, abs(m.Z), 'Color', c, 'LineWidth', 1.4, 'DisplayName', [s.id ' ' s.title]);
    semilogx(ax(2), m.fn, angle(m.Z)*180/pi, 'Color', c, 'LineWidth', 1.4);
    M = lab_model('zinf_raw', s.model, 0);
    loglog(ax(1), M.f, abs(M.H), '--', 'Color', c, 'HandleVisibility', 'off');
    semilogx(ax(2), M.f, angle(M.H)*180/pi, '--', 'Color', c);
    v = ''; if ~isempty(m.R), v = m.R(1).verdict; end
    vt{end+1} = chip(C, s.id, v); %#ok<AGROW>
end
if any1
    style(ax(1), C, [20 24000]); set(ax(1), 'YScale', 'log'); ylim(ax(1), [2 200]); ylabel(ax(1), '|Z| (ohm)');
    yline(ax(1), 4, ':', 'Color', C.bad, 'HandleVisibility', 'off');
    title(ax(1), {'Board input: measured (solid) vs model (dashed)', strjoin(vt, '   ')}, 'Interpreter', 'tex', 'Color', C.axfg);
    leg(ax(1), C, 'northwest');
    style(ax(2), C, [20 24000]); ylim(ax(2), [-90 90]); ylabel(ax(2), 'phase of Z (deg)'); xlabel(ax(2), 'frequency (Hz)');
else
    blank(ax(1), C, {'Board impedance: nothing measured yet', '(steps Z1, Z2, Z3 at the Zi/Nfield station)'}); blank(ax(2), C, '');
end
if isfield(L, 'Z4')
    m = L.Z4; v = ''; msg = ''; if ~isempty(m.R), v = m.R(1).verdict; msg = m.R(1).msg; end
    semilogx(ax(3), m.fn, abs(m.Z), 'Color', col(C, 1), 'LineWidth', 1.4, 'DisplayName', 'today');
    semilogx(ax(4), m.fn, angle(m.Z)*180/pi, 'Color', col(C, 1), 'LineWidth', 1.4);
    [ref, ok] = lab_model('woofer', '', m.setup.vent_mm, []);
    if ok
        semilogx(ax(3), ref.fn, abs(ref.Z), '--', 'Color', C.model, 'DisplayName', sprintf('Lab D %g mm', m.setup.vent_mm));
        semilogx(ax(4), ref.fn, angle(ref.Z)*180/pi, '--', 'Color', C.model);
    end
    style(ax(3), C, [5 500]); ylabel(ax(3), '|Z| (ohm)'); leg(ax(3), C, 'northeast');
    title(ax(3), {['Woofer in the box   ' chip(C, 'Z4', v)], msg}, 'Interpreter', 'tex', 'Color', C.axfg, 'FontSize', 10);
    style(ax(4), C, [5 500]); ylim(ax(4), [-90 90]); ylabel(ax(4), 'phase of Z (deg)'); xlabel(ax(4), 'frequency (Hz)');
    yline(ax(4), 0, ':', 'Color', C.model);
    title(ax(4), 'resonances: where the phase crosses 0 deg', 'FontWeight', 'normal', 'Color', C.axfg);
else
    blank(ax(3), C, {'Woofer in the box: nothing measured yet', '(step Z4)'}); blank(ax(4), C, '');
end
end

function nf_all(ax, C, runs)
P = lab_plan(); L = latest(runs); ids = {'N1', 'N2'}; vt = {}; m = [];
for j = 1:2
    if ~isfield(L, ids{j}), continue; end
    m = L.(ids{j}); s = P(strcmp({P.id}, ids{j})); c = col(C, j);
    semilogx(ax(1), m.fn, 20*log10(abs(m.H)), 'Color', c, 'LineWidth', 1.4, 'DisplayName', [s.id ' ' s.title]);
    semilogx(ax(2), m.fn, angle(m.H)*180/pi, 'Color', c, 'LineWidth', 1.2);
    [ref, ok] = lab_model('nf', erase(s.model, 'nf_'), m.setup.vent_mm, m.fn);
    if ok, semilogx(ax(1), m.fn, ref, '--', 'Color', c, 'DisplayName', sprintf('Lab D %s, %g mm', erase(s.model, 'nf_'), m.setup.vent_mm)); end
    v = ''; if ~isempty(m.R), v = m.R(1).verdict; end
    vt{end+1} = chip(C, s.id, v); %#ok<AGROW>
end
if isempty(m)
    blank(ax(1), C, {'Near field: nothing measured yet', '(steps N1, N2 at the Zi/Nfield station)'}); blank(ax(2), C, ''); return
end
style(ax(1), C, [5 2000]); ylabel(ax(1), '|p/V| (dB re 1 Pa/V)'); leg(ax(1), C, 'southwest');
title(ax(1), {sprintf('Near field, vent %g mm: today (solid) vs Lab D (dashed)', m.setup.vent_mm), strjoin(vt, '   ')}, 'Interpreter', 'tex', 'Color', C.axfg);
style(ax(2), C, [5 2000]); ylim(ax(2), [-180 180]); ylabel(ax(2), 'phase of p/V (deg)'); xlabel(ax(2), 'frequency (Hz)');
end

% =====================================================================
function L = latest(runs)
% latest run per step id; the day's own runs win over loaded manual runs
L = struct();
man = cellfun(@(m) isfield(m, 'manual') && m.manual, runs);
for m = [runs(man) runs(~man)]
    for k = 1:numel(m{1}.ids), L.(m{1}.ids{k}) = m{1}; end
end
end

function s = head(m, what)
s = sprintf('%s  (%s):  %s', strrep(m.file, '_', '\_'), char(datetime(m.time, 'Format', 'dd-MMM HH:mm')), what);
if isfield(m, 'manual') && m.manual, s = ['manual run  ' s]; end
end

function c = col(C, k)
c = C.curves(mod(k-1, size(C.curves, 1)) + 1, :);
end

function s = chip(C, id, v)
switch v
    case 'OK', c = C.ok; case 'CHECK', c = C.check; case 'BAD', c = C.bad; otherwise, c = C.none; v = '-';
end
s = sprintf('\\color[rgb]{%.2f,%.2f,%.2f}%s %s', c, id, v);
end

function style(a, C, xl)
set(a, 'XScale', 'log', 'Color', C.axbg, 'XColor', C.axfg, 'YColor', C.axfg, 'GridColor', C.grid, ...
    'MinorGridColor', C.grid, 'GridAlpha', 0.22, 'MinorGridAlpha', 0.10, 'FontSize', 11, 'Box', 'on', 'Visible', 'on');
grid(a, 'on'); set(a, 'XMinorGrid', 'on', 'YMinorGrid', 'off'); xlim(a, xl);
try, a.BackgroundColor = C.panel; catch, end      % uiaxes: the margin around the plot box
try, a.Toolbar.Visible = 'off'; catch, end
end

function leg(a, C, loc)
lg = legend(a, 'Location', loc, 'Interpreter', 'none', 'FontSize', 10);
set(lg, 'Color', C.axbg, 'TextColor', C.axfg, 'EdgeColor', C.line);
end

function blank(a, C, msg)
set(a, 'Visible', 'off', 'Color', C.axbg);
try, a.BackgroundColor = C.panel; catch, end
try, a.Toolbar.Visible = 'off'; catch, end
xlim(a, [0 1]); ylim(a, [0 1]);
text(a, 0.5, 0.5, msg, 'HorizontalAlignment', 'center', 'FontSize', 14, 'Color', C.muted, 'Interpreter', 'none');
end
