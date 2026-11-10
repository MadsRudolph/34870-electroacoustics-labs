function m = lab(what, varargin)
% LAB  One command for the whole lab day. Every measurement ends in graphs.
%      (The same thing with buttons: labgui.  Section by section in the editor: lab_run.m)
%
%   lab                 show the dashboard (everything measured today) + the step list
%   lab P1              measure one step, e.g. the woofer placement check
%   lab S               measure a whole run (S1, S2, S3 in one go: switch during the beeps)
%   lab({'S1','S3'})    any 1-3 chamber steps in one run
%   lab list            the step list only
%
%   Before measuring, a box shows what to set up; press Measure (or Cancel).
%   After measuring, the data are saved to lab-day/data/<date>/ and the dashboard
%   opens on the "Latest" tab: measured (solid) vs expected (dashed, shifted by
%   the fitted level), the difference underneath, and a verdict in the title
%   (green OK / orange CHECK / red BAD). All other tabs always show everything.
%
%   Name/Value: 'confirm' (default: true on the lab PC), 'Nav' (chamber, default
%   64), 'datadir' (default lab-day/data/<date>), 'note' (free text), 'set' (struct
%   overriding settings, e.g. struct('R_series', 32.9)), 'save' (dashboard PNGs, default true).
%   Settings: lab_setup.m, and on top of it the day's session.json once labgui has
%   saved one (so the GUI and these commands use the same values). Steps: lab_plan.m.

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'core'));
p = inputParser;
p.addParameter('confirm', usejava('desktop'));
p.addParameter('Nav', 64);
p.addParameter('datadir', '');
p.addParameter('note', '');
p.addParameter('set', struct());
p.addParameter('save', true);
p.parse(varargin{:});
o = p.Results;

L = labpaths();
datadir = o.datadir;
if isempty(datadir), S0 = lab_setup(); datadir = fullfile(L.data, S0.date); end
[S, src] = lab_settings(datadir);
if strcmp(src, 'session.json')
    fprintf('Settings: lab_setup.m + %s (saved by labgui): Out 1 %g dB, Out 2 %g dB, vent %g mm, R %g ohm\n', ...
        fullfile(datadir, 'session.json'), S.out1_gain, S.out2_gain, S.vent_mm, S.R_series);
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

[st, ~, label] = lab_steps(what);
I = lab_instructions(st, S, o.Nav);
fprintf('\n==== %s ====\n%s\nTakes about %.0f s: %s\n', label, strjoin(I.lines, newline), I.secs, I.timeline);
if o.confirm
    a = questdlg(I.lines, ['Measure ' label], 'Measure', 'Cancel', 'Measure');
    if ~strcmp(a, 'Measure'), fprintf('Cancelled.\n'); return; end
end

try
    [m, file, warn] = lab_measure(what, S, 'datadir', datadir, 'Nav', o.Nav, 'note', o.note);
catch err
    fprintf(2, '\nMeasurement failed: %s\nFIX: %s\n', err.message, lab_errfix(err));
    rethrow(err);
end
fprintf('Saved %s\n', file);
for i = 1:numel(warn), warning('lab:signal', '%s', warn{i}); end

m.R = lab_check(m);
[v, txt] = lab_advice(m, lab_runs(datadir));
fprintf('\nVerdict: %s\n  %s\n', v, strjoin(txt, sprintf('\n  ')));
lab_dash(datadir, 'focus', 'Latest', 'save', o.save);
end

function lab_list(P, datadir)
done = {};
runs = lab_runs(datadir);
for i = 1:numel(runs), done = [done runs{i}.ids]; end %#ok<AGROW>
fprintf('\n%-4s %-4s %-36s %s\n', 'step', 'run', 'what', 'done');
for i = 1:numel(P)
    fprintf('%-4s %-4s %-36s %s\n', P(i).id, P(i).grp, P(i).title, repmat('x', 1, any(strcmp(done, P(i).id))));
end
fprintf(['\nType  lab P1  (one step)  or  lab S  (the whole run S1-S3).  ' ...
    'The dashboard always shows everything.  Buttons instead: labgui\n']);
end
