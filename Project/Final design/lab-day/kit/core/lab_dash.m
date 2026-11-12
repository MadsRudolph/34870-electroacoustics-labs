function fig = lab_dash(datadir, varargin)
% LAB_DASH  The dashboard: everything measured in DATADIR, always redrawn from the files.
%
%   lab_dash                    today's folder (../data/<date>)
%   lab_dash(datadir, 'focus', 'Latest', 'save', true)
%
% Tabs: Plan (every step, its verdict and number) | Latest (the run just measured) |
%       Placement (P: vs Lab E) | System (S, + every 'all' run overlaid, + phase between
%       the two channels) | Flips (F) | 30 deg (A) | Impedance (Z) | Near field (N).
% Measured = solid, expected = dashed (shifted by the fitted level), difference underneath.
% Every tab is also saved as <datadir>/figures/<tab>.png.

p = inputParser;
p.addParameter('focus', 'Plan');
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;
L = labpaths;
S = lab_setup();
if nargin < 1 || isempty(datadir), datadir = fullfile(L.data, S.date); end
[~, day] = fileparts(datadir);
P = lab_plan();

% ---- load every run, newest last
runs = {};
d = dir(fullfile(datadir, '*.mat'));
if ~isempty(d)
    for i = 1:numel(d)
        m = load(fullfile(d(i).folder, d(i).name));
        [~, m.file] = fileparts(d(i).name);
        m.R = lab_check(m);
        runs{end+1} = m; %#ok<AGROW>
    end
    [~, i] = sort(cellfun(@(m) datenum(m.time), runs)); runs = runs(i); %#ok<DATNM>
end

% latest run per step id
latest = containers.Map();
for i = 1:numel(runs)
    for k = 1:numel(runs{i}.ids), latest(runs{i}.ids{k}) = [i k]; end
end

fig = findobj(0, 'Type', 'figure', 'Tag', 'labdash');
if isempty(fig)
    fig = figure('Tag', 'labdash', 'Name', 'Lab dashboard', 'NumberTitle', 'off', ...
        'Color', 'w', 'Position', [60 60 1250 800]);
end
clf(fig);
try, fig.Theme = 'light'; catch, end      % R2025a+: figures follow the desktop theme otherwise
tg = uitabgroup(fig);
tabs = struct();
for t = {'Plan', 'Latest', 'Placement', 'System', 'Flips', 'Deg30', 'Impedance', 'NearField'}
    tabs.(t{1}) = uitab(tg, 'Title', strrep(strrep(t{1}, 'Deg30', '30 deg'), 'NearField', 'Near field'), ...
        'BackgroundColor', 'w');
end

plan_tab(tabs.Plan, P, runs, latest, day);
if ~isempty(runs)
    run_tab(tabs.Latest, runs{end}, sprintf('Latest: %s (%s)', runs{end}.file, ...
        char(datetime(runs{end}.time, 'Format', 'HH:mm'))));
end
steps_tab(tabs.Placement, runs, latest, {'P1', 'P2', 'P3', 'P2d', 'P3d'}, 'Placement check vs Lab E (MiniDSP bypassed)');
system_tab(tabs.System, runs, latest);
grp_tab(tabs.Flips, runs, {'F0', 'F1', 'F2'}, 'Polarity flips (deep notch = the two drivers are in phase at the crossover)');
grp_tab(tabs.Deg30, runs, {'A1', 'A2', 'A3'}, '30 deg');
z_tab(tabs.Impedance, runs, latest, S);
nf_tab(tabs.NearField, runs, latest, S);

tg.SelectedTab = tabs.(o.focus);
drawnow;
if o.save && ~isempty(runs)
    fd = fullfile(datadir, 'figures');
    if ~exist(fd, 'dir'), mkdir(fd); end
    for t = fieldnames(tabs)'
        if isempty(tabs.(t{1}).Children), continue; end
        try
            tg.SelectedTab = tabs.(t{1}); drawnow;
            try, exportgraphics(tabs.(t{1}), fullfile(fd, [t{1} '.png']), 'Resolution', 110);
            catch, print(fig, fullfile(fd, [t{1} '.png']), '-dpng', '-r110'); end
        catch
        end
    end
    tg.SelectedTab = tabs.(o.focus);
end
end

% =====================================================================
function plan_tab(tab, P, runs, latest, day)
ax = axes(tab, 'Position', [0.02 0.02 0.96 0.92], 'Visible', 'off');
xlim(ax, [0 1]); n = numel(P) + 2; ylim(ax, [0 n]); set(ax, 'YDir', 'reverse');
text(ax, 0, 0.5, sprintf('Session %s: %d runs saved', day, numel(runs)), 'FontWeight', 'bold', 'FontSize', 12);
hdr = {'step', 'run', 'what', 'verdict', 'time', 'result'}; x = [0 0.04 0.08 0.30 0.36 0.41];
for j = 1:numel(hdr), text(ax, x(j), 1.4, hdr{j}, 'FontWeight', 'bold'); end
for i = 1:numel(P)
    y = i + 1.4;
    text(ax, x(1), y, P(i).id); text(ax, x(2), y, P(i).grp); text(ax, x(3), y, P(i).title, 'Interpreter', 'none');
    if isKey(latest, P(i).id)
        ik = latest(P(i).id); m = runs{ik(1)};
        r = m.R(strcmp({m.R.id}, P(i).id));
        extra = m.R(ismember({m.R.id}, {'bal', 'sum', 'F1n', 'F2n'}));
        msg = r.msg;
        if ik(2) == numel(m.ids) && ~isempty(extra)
            msg = [msg '  |  ' strjoin(arrayfun(@(e) sprintf('%s %s', e.verdict, e.msg), extra, 'UniformOutput', false), '  |  ')];
        end
        text(ax, x(4), y, r.verdict, 'Color', vcol(r.verdict), 'FontWeight', 'bold');
        text(ax, x(6), y, msg, 'Interpreter', 'none', 'FontSize', 7);
        text(ax, x(5), y, char(datetime(m.time, 'Format', 'HH:mm')));
    else
        text(ax, x(4), y, '-', 'Color', [0.6 0.6 0.6]);
    end
end
end

function run_tab(tab, m, ttl)
% one run: every step against its expectation + difference
if strcmp(m.station, 'zinf')
    z_one(tab, m, ttl); return
end
P = lab_plan(); fn = m.fn(:);
a1 = subplot(3, 1, [1 2], 'Parent', tab); hold(a1, 'on');
a2 = subplot(3, 1, 3, 'Parent', tab); hold(a2, 'on');
c = lines(numel(m.ids)); vt = {}; ytop = -Inf;
for k = 1:numel(m.ids)
    s = P(strcmp({P.id}, m.ids{k})); r = m.R(strcmp({m.R.id}, s.id));
    y = 20*log10(abs(m.H(:,k)));
    ymod = lab_model('chamber', s.model, s.angle, fn);
    semilogx(a1, fn, y, 'Color', c(k,:), 'LineWidth', 1.3, 'DisplayName', sprintf('%s %s', s.id, s.title));
    semilogx(a1, fn, ymod + r.offset, '--', 'Color', c(k,:), 'HandleVisibility', 'off');
    rr = lab_smooth(fn, y - ymod - r.offset); rr(fn < s.band(1) | fn > s.band(2)) = NaN; ytop = max([ytop; y(fn > 50)]);
    semilogx(a2, fn, rr, 'Color', c(k,:), 'LineWidth', 1.2);
    vt{end+1} = sprintf('\\color[rgb]{%g,%g,%g}%s %s', vcol(r.verdict), s.id, r.verdict); %#ok<AGROW>
end
for e = m.R(ismember({m.R.id}, {'bal', 'sum', 'F1n', 'F2n'}))
    vt{end+1} = sprintf('\\color[rgb]{%g,%g,%g}%s %s', vcol(e.verdict), e.id, e.verdict); %#ok<AGROW>
end
style(a1, [50 20000]); ylabel(a1, '|p/V| (dB re 1 Pa/V)');
legend(a1, 'Location', 'southwest', 'Interpreter', 'none');
ylim(a1, [ytop - 40, ytop + 5]);
title(a1, {ttl, strjoin(vt, '   ')}, 'Interpreter', 'tex');
style(a2, [50 20000]); ylim(a2, [-6 6]); yline(a2, -1.5, ':k', 'HandleVisibility', 'off'); yline(a2, 1.5, ':k', 'HandleVisibility', 'off');
ylabel(a2, {'meas - expected', '(dB, 1/6 oct, in band)'}); xlabel(a2, 'frequency (Hz)');
txt = strjoin(arrayfun(@(e) sprintf('%s: %s', e.id, e.msg), m.R, 'UniformOutput', false), newline);
annotation(tab, 'textbox', [0.13 0.005 0.8 0.04], 'String', txt, 'EdgeColor', 'none', ...
    'FontSize', 7, 'Interpreter', 'none', 'VerticalAlignment', 'bottom');
end

function steps_tab(tab, runs, latest, ids, ttl)
% the latest measurement of each step in IDS, each against its own expectation
if ~any(cellfun(@(i) isKey(latest, i), ids)), notyet(tab, ttl); return; end
a1 = subplot(3, 1, [1 2], 'Parent', tab);
a2 = subplot(3, 1, 3, 'Parent', tab);
steps_draw(a1, a2, runs, latest, ids, ttl);
end

function steps_draw(a1, a2, runs, latest, ids, ttl)
P = lab_plan(); hold(a1, 'on'); hold(a2, 'on');
have = ids(cellfun(@(i) isKey(latest, i), ids));
c = lines(numel(have)); vt = {}; ytop = -Inf;
for j = 1:numel(have)
    ik = latest(have{j}); m = runs{ik(1)}; k = ik(2); fn = m.fn(:);
    s = P(strcmp({P.id}, have{j})); r = m.R(strcmp({m.R.id}, s.id));
    y = 20*log10(abs(m.H(:,k))); ymod = lab_model('chamber', s.model, s.angle, fn);
    semilogx(a1, fn, y, 'Color', c(j,:), 'LineWidth', 1.3, 'DisplayName', sprintf('%s %s', s.id, s.title));
    semilogx(a1, fn, ymod + r.offset, '--', 'Color', c(j,:), 'HandleVisibility', 'off');
    rr = lab_smooth(fn, y - ymod - r.offset); rr(fn < s.band(1) | fn > s.band(2)) = NaN; ytop = max([ytop; y(fn > 50)]);
    semilogx(a2, fn, rr, 'Color', c(j,:), 'LineWidth', 1.2);
    vt{end+1} = sprintf('\\color[rgb]{%g,%g,%g}%s %s (%.1f dB rms)', vcol(r.verdict), s.id, r.verdict, r.shape); %#ok<AGROW>
end
style(a1, [50 20000]); ylabel(a1, '|p/V| (dB re 1 Pa/V)'); legend(a1, 'Location', 'southwest', 'Interpreter', 'none');
ylim(a1, [ytop - 40, ytop + 5]);
title(a1, {ttl, strjoin(vt, '   ')}, 'Interpreter', 'tex');
style(a2, [50 20000]); ylim(a2, [-6 6]); yline(a2, -1.5, ':k'); yline(a2, 1.5, ':k');
ylabel(a2, {'meas - expected', '(dB, 1/6 oct, in band)'}); xlabel(a2, 'frequency (Hz)');
end

function system_tab(tab, runs, latest)
P = lab_plan();
ids = {'S1', 'S2', 'S3', 'S4', 'S5'};
if ~any(cellfun(@(i) isKey(latest, i), ids)), notyet(tab, 'System (MiniDSP on)'); return; end
steps_draw(subplot(5, 2, [1 4], 'Parent', tab), subplot(5, 2, [5 6], 'Parent', tab), runs, latest, ids, ...
    'System, MiniDSP on: latest of each step');
% every 'all' state measured today (drift / changes)
a3 = subplot(5, 2, [7 9], 'Parent', tab);
hold(a3, 'on'); n = 0;
for i = 1:numel(runs)
    m = runs{i}; k = find(ismember(m.ids, {'S3', 'F0'}));
    if isempty(k) || ~strcmp(m.station, 'chamber'), continue; end
    semilogx(a3, m.fn, lab_smooth(m.fn, 20*log10(abs(m.H(:,k)))), 'LineWidth', 1.1, ...
        'DisplayName', sprintf('%s %s', m.file, char(datetime(m.time, 'Format', 'HH:mm'))));
    n = n + 1;
end
style(a3, [50 20000]); title(a3, sprintf('every "all" run today (%d): should overlap', n));
ylabel(a3, 'dB re 1 Pa/V (1/6 oct)'); if n, legend(a3, 'Location', 'southwest', 'Interpreter', 'none', 'FontSize', 7); end
% phase between the channels in the latest S run (same run = same clock)
a4 = subplot(5, 2, [8 10], 'Parent', tab); hold(a4, 'on');
iS = find(cellfun(@(m) all(ismember({'S1', 'S2'}, m.ids)), runs), 1, 'last');
if ~isempty(iS)
    m = runs{iS}; w = m.H(:, strcmp(m.ids, 'S1')); t = m.H(:, strcmp(m.ids, 'S2'));
    near = abs(20*log10(abs(w)) - 20*log10(abs(t))) < 15;
    ph = angle(w ./ t) * 180/pi; ph(~near) = NaN;
    semilogx(a4, m.fn, ph, 'k', 'LineWidth', 1.2);
    yline(a4, 0, ':'); ylim(a4, [-180 180]); style(a4, [100 2000]);
    title(a4, sprintf('woofer - mid/tw phase, run %s (about 0 deg at 325 Hz = in phase)', m.file), 'Interpreter', 'none');
    ylabel(a4, 'deg'); xlabel(a4, 'frequency (Hz)');
else
    axis(a4, 'off'); text(a4, 0.1, 0.5, 'Measure the run S (S1, S2, S3 together) to see the phase between the channels.');
end
end

function grp_tab(tab, runs, ids, ttl)
% the latest run that holds all of IDS
i = find(cellfun(@(m) all(ismember(ids, m.ids)), runs), 1, 'last');
if isempty(i), notyet(tab, [ttl ': measure the whole run (lab ' ids{1}(1) ')']); return; end
run_tab(tab, runs{i}, sprintf('%s: run %s', ttl, runs{i}.file));
end

function z_tab(tab, runs, latest, S)
ids = {'Z1', 'Z2', 'Z3', 'Z4'};
if ~any(cellfun(@(i) isKey(latest, i), ids)), notyet(tab, 'Impedance (Zi station)'); return; end
P = lab_plan();
a1 = subplot(2, 2, [1 3], 'Parent', tab); hold(a1, 'on');
a2 = subplot(2, 2, 2, 'Parent', tab); hold(a2, 'on');
c = lines(3); vt = {};
for j = 1:3
    if ~isKey(latest, ids{j}), continue; end
    ik = latest(ids{j}); m = runs{ik(1)}; s = P(strcmp({P.id}, ids{j})); r = m.R(1);
    loglog(a1, m.fn, abs(m.Z), 'Color', c(j,:), 'LineWidth', 1.3, 'DisplayName', [s.id ' ' s.title]);
    Zm = lab_model('zinf', s.model, 0, m.fn);
    loglog(a1, m.fn, 10.^(Zm/20), '--', 'Color', c(j,:), 'HandleVisibility', 'off');
    vt{end+1} = sprintf('\\color[rgb]{%g,%g,%g}%s %s', vcol(r.verdict), s.id, r.verdict); %#ok<AGROW>
end
set(a1, 'XScale', 'log', 'YScale', 'log'); grid(a1, 'on'); xlim(a1, [20 24000]); ylim(a1, [2 200]);
ylabel(a1, '|Z| (\Omega)'); xlabel(a1, 'frequency (Hz)'); legend(a1, 'Location', 'northwest');
title(a1, {'Board input: measured (solid) vs model (dashed)', strjoin(vt, '   ')});
yline(a1, 4, ':r', '4 \Omega', 'HandleVisibility', 'off');
if isKey(latest, 'Z4')
    ik = latest('Z4'); m = runs{ik(1)}; r = m.R(1);
    semilogx(a2, m.fn, abs(m.Z), 'k', 'LineWidth', 1.3, 'DisplayName', 'today');
    [ref, ok] = lab_model('woofer', '', m.setup.vent_mm, []);
    if ok, semilogx(a2, ref.fn, abs(ref.Z), 'r--', 'DisplayName', sprintf('Lab D %d mm', m.setup.vent_mm)); end
    set(a2, 'XScale', 'log'); grid(a2, 'on'); xlim(a2, [5 500]); legend(a2);
    title(a2, sprintf('\\color[rgb]{%g,%g,%g}Z4 woofer %s', vcol(r.verdict), r.verdict));
    ylabel(a2, '|Z| (\Omega)');
    a3 = subplot(2, 2, 4, 'Parent', tab); axis(a3, 'off');
    text(a3, 0, 0.6, r.msg, 'Interpreter', 'none');
end
end

function z_one(tab, m, ttl)
a = axes(tab); s = lab_plan(); s = s(strcmp({s.id}, m.ids{1})); r = m.R(1);
if isfield(m, 'Z')
    loglog(a, m.fn, abs(m.Z), 'k', 'LineWidth', 1.3); hold(a, 'on');
    if startsWith(s.model, 'board')
        Zm = lab_model('zinf', s.model, 0, m.fn); loglog(a, m.fn, 10.^(Zm/20), 'r--');
        legend(a, 'measured', 'model'); xlim(a, [20 24000]);
    else
        [ref, ok] = lab_model('woofer', '', m.setup.vent_mm, []);
        if ok, loglog(a, ref.fn, abs(ref.Z), 'r--'); legend(a, 'today', 'Lab D'); end
        xlim(a, [5 500]);
    end
    ylabel(a, '|Z| (\Omega)');
else
    semilogx(a, m.fn, 20*log10(abs(m.H)), 'k', 'LineWidth', 1.3); hold(a, 'on');
    [ref, ok] = lab_model('nf', erase(s.model, 'nf_'), m.setup.vent_mm, m.fn);
    if ok, semilogx(a, m.fn, ref, 'r--'); legend(a, 'today', 'Lab D'); end
    xlim(a, [5 2000]); ylabel(a, '|p/V| (dB re 1 Pa/V)');
end
grid(a, 'on'); xlabel(a, 'frequency (Hz)');
title(a, {ttl, sprintf('\\color[rgb]{%g,%g,%g}%s %s', vcol(r.verdict), s.id, r.verdict)});
annotation(tab, 'textbox', [0.13 0.005 0.8 0.04], 'String', r.msg, 'EdgeColor', 'none', 'Interpreter', 'none');
end

function nf_tab(tab, runs, latest, S)
ids = {'N1', 'N2'};
if ~any(cellfun(@(i) isKey(latest, i), ids)), notyet(tab, 'Near field (Zi station)'); return; end
P = lab_plan(); a = axes(tab); hold(a, 'on'); c = lines(2); vt = {};
for j = 1:2
    if ~isKey(latest, ids{j}), continue; end
    ik = latest(ids{j}); m = runs{ik(1)}; s = P(strcmp({P.id}, ids{j})); r = m.R(1);
    semilogx(a, m.fn, 20*log10(abs(m.H)), 'Color', c(j,:), 'LineWidth', 1.3, 'DisplayName', [s.id ' ' s.title]);
    [ref, ok] = lab_model('nf', erase(s.model, 'nf_'), m.setup.vent_mm, m.fn);
    if ok, semilogx(a, m.fn, ref, '--', 'Color', c(j,:), 'DisplayName', sprintf('Lab D %d mm', m.setup.vent_mm)); end
    vt{end+1} = sprintf('\\color[rgb]{%g,%g,%g}%s %s', vcol(r.verdict), s.id, r.verdict); %#ok<AGROW>
end
set(a, 'XScale', 'log'); grid(a, 'on'); xlim(a, [5 2000]);
ylabel(a, '|p/V| (dB re 1 Pa/V)'); xlabel(a, 'frequency (Hz)'); legend(a, 'Location', 'southwest');
title(a, {sprintf('Near field, vent %d mm: today (solid) vs Lab D (dashed)', m.setup.vent_mm), strjoin(vt, '   ')});
end

function notyet(tab, ttl)
a = axes(tab, 'Visible', 'off');
text(a, 0.5, 0.5, {ttl, '', 'nothing measured yet'}, 'HorizontalAlignment', 'center', 'FontSize', 13, 'Color', [0.5 0.5 0.5]);
end

function style(a, xl)
set(a, 'XScale', 'log'); grid(a, 'on'); grid(a, 'minor'); xlim(a, xl); box(a, 'on');
end

function c = vcol(v)
switch v
    case 'OK',    c = [0 0.55 0];
    case 'CHECK', c = [0.9 0.5 0];
    otherwise,    c = [0.85 0 0];
end
end
