function plot_project(which, varargin)
% PLOT_PROJECT  Graphs of the anechoic measurements, one figure per run, saved as PNG + FIG.
%
%   plot_project                    every ../data/project_*.mat, plus an overview figure
%   plot_project('R1_split_0_3')    one run (file name without 'project_' and '.mat')
%   plot_project(m)                 a struct straight from measure_project
%
%   Name/Value:
%     'model'   true (default): dashed model curves, shifted by the fitted level
%     'smooth'  0 (default, raw) or e.g. 6 for 1/6-octave smoothing of the magnitude
%     'labels'  cell array overriding the state names in the legend, e.g. when a
%               state was not switched in time: {'mid','tw','tw (not switched)'}
%     'save'    true (default): ../figures/<tag>.png and .fig
%
% Each run figure: top = |p/V| in dB for every state of the run (dashed = model),
% bottom = phase DIFFERENCE between the two drivers of the run (woofer - midtw,
% or mid - tw) where they are within 15 dB of each other. Only states in the same
% run share a clock, so only this difference is meaningful (the absolute phase
% carries ~47 ms of USB/DSP latency). In-phase crossover -> about 0 deg.
% The overview figure overlays the 'all' state of every 0 deg run (drift check).

p = inputParser;
p.addParameter('model', true);
p.addParameter('smooth', 0);
p.addParameter('labels', {});
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;

if ~exist('labpaths', 'file'), addpath(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'kit', 'core')); end
L = labpaths;
datadir = L.data;
figdir = L.figures;
if o.save && ~exist(figdir, 'dir'), mkdir(figdir); end

if nargin < 1 || isempty(which)
    d = dir(fullfile(datadir, 'project_*.mat'));
    [~, i] = sort([d.datenum]); d = d(i);
    allruns = {};
    for i = 1:numel(d)
        m = load(fullfile(d(i).folder, d(i).name));
        m.tag = erase(erase(d(i).name, 'project_'), '.mat');   % keeps the _2, _3
        one_run(m, o, figdir);
        allruns{end+1} = m; %#ok<AGROW>
    end
    overview(allruns, o, figdir);
    return
end
if isstruct(which)
    m = which;
else
    f = fullfile(datadir, ['project_' char(which) '.mat']);
    m = load(f);
    m.tag = char(which);
end
one_run(m, o, figdir);
end

% ---------------------------------------------------------------------------
function one_run(m, o, figdir)
fn = m.fn(:);
ns = numel(m.states);
labels = m.states;
if ~isempty(o.labels), labels = o.labels; end
[T, hdr, fmod] = model_table(m.angle_deg);

fig = figure('Name', m.tag, 'Color', 'w', 'Position', [100 100 900 700]);
try, theme(fig, 'light'); end
cols = lines(max(ns, 3));
ax1 = subplot(3,1,[1 2]); hold on; grid on; box on
ax2 = subplot(3,1,3);     hold on; grid on; box on
for s = 1:ns
    y = 20*log10(abs(m.H(:,s)));
    if o.smooth > 0, y = smooth_oct(fn, y, o.smooth); end
    semilogx(ax1, fn, y, 'Color', cols(s,:), 'LineWidth', 1.4, 'DisplayName', labels{s});
    loud = 20*log10(abs(m.H(:,s))) > max(20*log10(abs(m.H(:,s)))) - 25;
    if o.model && ~isempty(T)
        ire = find(strcmp(hdr, [m.states{s} '_re'])); iim = find(strcmp(hdr, [m.states{s} '_im']));
        if ~isempty(ire)
            ymod = interp1(log(fmod), 20*log10(abs(T(:,ire) + 1j*T(:,iim))), log(fn), 'linear', NaN);
            kk = ~isnan(ymod) & loud & fn >= 150 & fn <= 15000;
            off = median(y(kk) - ymod(kk));
            semilogx(ax1, fn, ymod + off, '--', 'Color', cols(s,:), 'LineWidth', 1, ...
                'DisplayName', sprintf('model %s (%+.1f dB)', m.states{s}, off));
        end
    end
end
set([ax1 ax2], 'XScale', 'log', 'XLim', [50 20000]);
xline(ax1, 325, ':k', 'HandleVisibility', 'off');
top = max(20*log10(abs(m.H(fn >= 60 & fn <= 18000, :))), [], 'all');
ylim(ax1, [10*floor((top - 40)/10), 10*ceil((top + 3)/10)]);
ylabel(ax1, '|p/V|  (dB re 1 Pa/V)');
ttl = sprintf('%s   %g deg   %s', m.tag, m.angle_deg, datestr(m.time, 'HH:MM'));
if isfield(m, 'note') && ~isempty(m.note), ttl = [ttl '   (' m.note ')']; end
title(ax1, ttl, 'Interpreter', 'none');
legend(ax1, 'Location', 'southwest', 'Interpreter', 'none');
% phase DIFFERENCE between the two driver states of the run (same run = same
% clock, so the ~47 ms latency cancels). Shown only where the two are within
% 15 dB of each other, i.e. around the crossover. LR4 in phase -> about 0 deg.
pairs = {'woofer','midtw'; 'mid','tw'; 'woofer','mid'};
pr = [];
for i = 1:size(pairs,1)
    a = find(strcmp(m.states, pairs{i,1})); b = find(strcmp(m.states, pairs{i,2}));
    if ~isempty(a) && ~isempty(b), pr = [a b]; break, end
end
if ~isempty(pr)
    dph = rad2deg(angle(m.H(:,pr(1)) ./ m.H(:,pr(2))));
    dl = abs(20*log10(abs(m.H(:,pr(1)) ./ m.H(:,pr(2)))));
    La = 20*log10(abs(m.H(:,pr(1)))); Lb = 20*log10(abs(m.H(:,pr(2))));
    dph(dl > 15 | max(La, Lb) < max([La; Lb]) - 30) = NaN;   % skip where both are silent
    semilogx(ax2, fn, dph, '.-', 'Color', [0.2 0.2 0.2], 'MarkerSize', 6);
    kx = find(dl == min(dl(fn > 100 & fn < 15000)), 1);
    title(ax2, sprintf('phase %s - %s: %+.0f deg where they are equal (%.0f Hz)', ...
        labels{pr(1)}, labels{pr(2)}, dph(kx), fn(kx)), 'FontWeight', 'normal', 'Interpreter', 'none');
    xline(ax2, fn(kx), ':r', 'HandleVisibility', 'off');
elseif any(startsWith(m.states, 'flip')) && any(strcmp(m.states, 'all'))
    ia = find(strcmp(m.states, 'all'));
    txt = {};
    for s = find(startsWith(m.states, 'flip'))
        d = 20*log10(abs(m.H(:,s) ./ m.H(:,ia)));
        semilogx(ax2, fn, d, 'Color', cols(s,:), 'LineWidth', 1.2);
        if strcmp(m.states{s}, 'flipW'), b = [200 600]; else, b = [2000 6000]; end
        kk = find(fn >= b(1) & fn <= b(2)); [dm, j] = min(d(kk));
        txt{end+1} = sprintf('%s notch %.0f Hz, %.1f dB', labels{s}, fn(kk(j)), dm); %#ok<AGROW>
    end
    title(ax2, ['re ''all'': ' strjoin(txt, ',   ')], 'FontWeight', 'normal', 'Interpreter', 'none');
    ylim(ax2, [-40 10]); ylabel(ax2, 'flip / all (dB)');
else
    text(ax2, 0.5, 0.5, 'no driver pair in this run', 'Units', 'normalized', 'HorizontalAlignment', 'center');
end
if ~(any(startsWith(m.states, 'flip')) && isempty(pr))
    ylim(ax2, [-180 180]); yticks(ax2, -180:90:180);
    ylabel(ax2, '\Delta phase (deg)');
end
xlabel(ax2, 'frequency (Hz)');
xline(ax2, 325, ':k', 'HandleVisibility', 'off');
linkaxes([ax1 ax2], 'x');
if o.save
    exportgraphics(fig, fullfile(figdir, [m.tag '.png']), 'Resolution', 150);
    savefig(fig, fullfile(figdir, [m.tag '.fig']));
    fprintf('figure -> figures/%s.png\n', m.tag);
end
end

% ---------------------------------------------------------------------------
function overview(runs, o, figdir)
if isempty(runs), return; end
fig = figure('Name', 'overview: all states', 'Color', 'w', 'Position', [150 150 900 500]);
try, theme(fig, 'light'); end
hold on; grid on; box on
for i = 1:numel(runs)
    m = runs{i};
    s = find(strcmp(m.states, 'all'));
    if isempty(s) || m.angle_deg ~= 0, continue; end
    y = 20*log10(abs(m.H(:,s)));
    y = smooth_oct(m.fn(:), y, max(o.smooth, 6));
    semilogx(m.fn, y, 'LineWidth', 1.3, 'DisplayName', sprintf('%s (%s)', m.tag, datestr(m.time, 'HH:MM')));
end
set(gca, 'XScale', 'log', 'XLim', [50 20000]);
yl = ylim; ylim([max(yl(1), yl(2) - 40) yl(2)]);
xlabel('frequency (Hz)'); ylabel('|p/V|  (dB re 1 Pa/V), 1/6 oct');
title('''all'' state of every 0 deg run (should overlap once the setup is final)');
legend('Location', 'southwest', 'Interpreter', 'none');
if o.save
    exportgraphics(fig, fullfile(figdir, 'overview_all.png'), 'Resolution', 150);
    savefig(fig, fullfile(figdir, 'overview_all.fig'));
end
end

% ---------------------------------------------------------------------------
function [T, hdr, fmod] = model_table(ang)
T = []; hdr = {}; fmod = []; L = labpaths;
switch ang
    case 0,  f = fullfile(L.model, 'expected_on.csv');
    case 30, f = fullfile(L.model, 'expected_off30.csv');
    otherwise, return
end
if ~exist(f, 'file'), return; end
T = readmatrix(f, 'NumHeaderLines', 1);
fid = fopen(f); hdr = strsplit(strtrim(fgetl(fid)), ','); fclose(fid);
fmod = T(:,1);
end

function y = smooth_oct(f, x, n)
% 1/n-octave smoothing on the measurement grid (NaN-safe)
lf = log2(f); y = nan(size(x));
for i = 1:numel(f)
    y(i) = mean(x(abs(lf - lf(i)) <= 1/(2*n)), 'omitnan');
end
end
