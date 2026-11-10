function m = lab(what, varargin)
% LAB  One command for the whole lab day. Every measurement ends in graphs.
%
%   lab                 show the dashboard (everything measured today) + the step list
%   lab P1              measure one step, e.g. the woofer placement check
%   lab S               measure a whole run (S1, S2, S3 in one go: switch during the beeps)
%   lab({'S1','S3'})    any 1-3 chamber steps in one run
%   lab list            the step list only
%
%   Before measuring, a box shows what to set up; press Measure (or Cancel).
%   After measuring, the data are saved to ../data/<date>/ and the dashboard
%   opens on the "Latest" tab: measured (solid) vs expected (dashed, shifted by
%   the fitted level), the difference underneath, and a verdict in the title
%   (green OK / orange CHECK / red BAD). All other tabs always show everything.
%
%   Name/Value: 'confirm' (default: true on the lab PC), 'Nav' (chamber, default
%   64), 'datadir' (default ../data/<date>), 'note' (free text), 'set' (struct
%   overriding settings), 'save' (dashboard PNGs, default true), 'demo' (true =
%   no hardware: stand-in routines, data in ../demo_data/<date>).
%   Settings of the day (Out 1 gain, vent, series R ...) live in lab_setup.m; what
%   was changed in the GUI today (labgui, Settings panel) is used on top of it.
%   Steps live in lab_plan.m. The same thing with buttons and lamps: labgui.
%   Everything that is only called lives in core/ (no need to open it).

p = inputParser;
p.addParameter('confirm', usejava('desktop'));
p.addParameter('Nav', 64);
p.addParameter('datadir', '');
p.addParameter('note', '');
p.addParameter('set', struct());      % override settings, e.g. struct('R_series', 32.9)
p.addParameter('save', true);         % save the dashboard tabs as PNG
p.addParameter('demo', false);        % true: no hardware, stand-in routines, data in demo_data/
p.parse(varargin{:});
o = p.Results;

addpath(fullfile(fileparts(mfilename('fullpath')), 'core'));    % everything that is only called
L = labpaths;
S0 = lab_setup();
datadir = o.datadir;
if isempty(datadir)
    if o.demo, datadir = fullfile(L.demodata, S0.date); else, datadir = fullfile(L.data, S0.date); end
end
S = lab_settings(datadir);            % lab_setup.m + what was changed in the GUI today (settings.json)
for f = fieldnames(S0)'
    if ~isequaln(S.(f{1}), S0.(f{1}))
        fprintf('Setting changed in the GUI today: %s = %s (lab_setup.m says %s)\n', f{1}, ...
            strtrim(evalc('disp(S.(f{1}))')), strtrim(evalc('disp(S0.(f{1}))')));
    end
end
for f = fieldnames(o.set)', S.(f{1}) = o.set.(f{1}); end
P = lab_plan();
m = [];

if nargin < 1 || isempty(what)
    lab_list(P, datadir);
    lab_dash(datadir);
    return
end
if (ischar(what) || isstring(what)) && strcmpi(what, 'list')
    lab_list(P, datadir); return
end

% ---- which steps, and what to set up
[st, ~, label] = lab_steps(what);
I = lab_instructions(st, S);
fprintf('\n==== %s ====\n%s\n', label, strjoin(I.lines, newline));
if o.confirm
    a = questdlg(I.lines, ['Measure ' label], 'Measure', 'Cancel', 'Measure');
    if ~strcmp(a, 'Measure'), fprintf('Cancelled.\n'); return; end
end

% ---- measure and save
T = lab_timeline(st, o.Nav);
fprintf('Measuring about %.0f s ...\n', T.total);
demo = [];
if o.demo, demo = struct('speed', 15, 'fault', 'none'); end
[m, file, W] = lab_measure(what, S, datadir, 'Nav', o.Nav, 'note', o.note, 'demo', demo);
fprintf('Saved %s\n', file);

% ---- warnings that matter at once
for w = W
    if strcmp(w.level, 'warn'), warning('lab:measure', '%s %s', w.msg, w.fix); else, fprintf('%s\n', w.msg); end
end

R = lab_check(m);
for i = 1:numel(R), fprintf('  %-4s %-6s %s\n', R(i).id, R(i).verdict, R(i).msg); end
lab_dash(datadir, 'focus', 'Latest', 'save', o.save);
end

function lab_list(P, datadir)
done = {};
if exist(datadir, 'dir')
    d = dir(fullfile(datadir, '*.mat'));
    for i = 1:numel(d), w = load(fullfile(d(i).folder, d(i).name), 'ids'); done = [done w.ids]; end %#ok<AGROW>
end
fprintf('\n%-4s %-4s %-36s %s\n', 'step', 'run', 'what', 'done');
for i = 1:numel(P)
    fprintf('%-4s %-4s %-36s %s\n', P(i).id, P(i).grp, P(i).title, repmat('x', 1, any(strcmp(done, P(i).id))));
end
fprintf(['\nType  lab P1  (one step)  or  lab S  (the whole run S1-S3).  ' ...
    'The dashboard always shows everything.\n']);
end
