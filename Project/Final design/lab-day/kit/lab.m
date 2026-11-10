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
%   overriding lab_setup fields), 'save' (dashboard PNGs, default true).
%   Settings of the day (Out 1 gain, vent, series R ...) live in lab_setup.m.
%   Steps live in lab_plan.m.

p = inputParser;
p.addParameter('confirm', usejava('desktop'));
p.addParameter('Nav', 64);
p.addParameter('datadir', '');
p.addParameter('note', '');
p.addParameter('set', struct());      % override lab_setup fields, e.g. struct('R_series', 32.9)
p.addParameter('save', true);         % save the dashboard tabs as PNG
p.parse(varargin{:});
o = p.Results;

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'matlab'));                        % zinf_calc
S = lab_setup();
for f = fieldnames(o.set)', S.(f{1}) = o.set.(f{1}); end
datadir = o.datadir;
if isempty(datadir), datadir = fullfile(here, '..', 'data', S.date); end
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

% ---- which steps
if iscell(what), ids = what;
elseif any(strcmp({P.grp}, char(what))) && ~any(strcmp({P.id}, char(what)))
    ids = {P(strcmp({P.grp}, char(what))).id};
else, ids = {char(what)};
end
[ok, idx] = ismember(ids, {P.id});
assert(all(ok), 'Unknown step(s): %s. Type: lab list', strjoin(ids(~ok), ', '));
st = P(idx);
assert(numel(unique({st.station})) == 1, 'Chamber and Zi/Nfield steps cannot share a run.');
assert(numel(unique([st.angle])) == 1, 'All steps of a run must have the same angle.');
station = st(1).station;
if strcmp(station, 'zinf'), assert(numel(st) == 1, 'Zi/Nfield: one step per run.'); end
assert(numel(st) <= 3, 'At most 3 steps in one run (the course routine).');
if numel(st) > 1 && all(strcmp({st.grp}, st(1).grp)) && sum(strcmp({P.grp}, st(1).grp)) == numel(st)
    label = st(1).grp;
else
    label = strjoin(ids, '+');
end

% ---- instructions
txt = {};
for k = 1:numel(st)
    if k == 1, pre = 'NOW'; else, pre = sprintf('During beeps %d', k-1); end
    txt{end+1} = sprintf('%s  [%s] %s: %s', pre, st(k).id, st(k).title, st(k).setup); %#ok<AGROW>
end
if strcmp(station, 'chamber')
    txt{end+1} = sprintf('MiniDSP %s. Out 1 %g dB, Out 2 %g dB. Angle %d deg.', ...
        upper(st(1).dsp), S.out1_gain, S.out2_gain, st(1).angle);
end
fprintf('\n==== %s ====\n%s\n', label, strjoin(txt, newline));
if o.confirm
    a = questdlg(txt, ['Measure ' label], 'Measure', 'Cancel', 'Measure');
    if ~strcmp(a, 'Measure'), fprintf('Cancelled.\n'); return; end
end

% ---- measure
course = fullfile(here, '..', '..', '..', '..');
m = struct('label', label, 'ids', {ids}, 'station', station, 'angle', st(1).angle, ...
    'dsp', st(1).dsp, 'setup', S, 'note', o.note, 'time', datetime('now'));
if strcmp(station, 'chamber')
    if isempty(which('meas_mag_spec2_SoundCard_LabE')), addpath(fullfile(course, 'Lab E', 'matlab', 'course')); end
    n = numel(st);
    fprintf('Measuring about %.0f s ...\n', n*(o.Nav+1) + (n-1)*30);
    [fn, specn, f, spec, ch] = meas_mag_spec2_SoundCard_LabE(50, 20000, 48, 1, o.Nav, S.UmikSN, 0, n);
    m.fn = fn(:);
    m.H = reshape(specn(:,2,:) ./ specn(:,1,:), numel(fn), n);
    m.peak = reshape(max(abs(ch), [], 1), 2, n);
    m.Nav = o.Nav;
else
    if isempty(which('meas_mag_spec2_LabD')), addpath(fullfile(course, 'Lab D', 'matlab', 'course')); end
    kind = st.model;
    nf = startsWith(kind, 'nf');
    if ~nf, assert(S.R_series > 20 && S.R_series < 50, ...
            'Set R_series in lab_setup.m to the multimeter value of the series resistor (about 32.9).'); end
    if nf || strcmp(kind, 'woofer'), f1 = 1; f2 = 10000; else, f1 = 20; f2 = 24000; end
    Nav = 1 + 3*nf;
    [fn, specn, f, spec, ch] = meas_mag_spec2_LabD(f1, f2, 48, 0.125, Nav);
    r = zinf_calc(specn, ch, ternary(nf, 'nearfield', 'impedance'), S.R_series, S.NexusVperPa, 'auto');
    m.fn = fn(:);
    if nf, m.H = r.H; else, m.Z = r.Z; end
    m.k_amp = r.k; m.dc_AI0 = r.dc_AI0; m.clip = r.clip; m.peak = max(abs(ch));
    m.Nav = Nav;
end
m.specn = specn; m.spec = spec; m.f = f(:); m.ch = ch;

if ~exist(datadir, 'dir'), mkdir(datadir); end
file = fullfile(datadir, [label '.mat']); k = 2;
while exist(file, 'file'), file = fullfile(datadir, sprintf('%s_%d.mat', label, k)); k = k + 1; end
save(file, '-struct', 'm');
[~, m.file] = fileparts(file);
fprintf('Saved %s\n', file);

% ---- warnings that matter at once
if strcmp(station, 'chamber')
    if any(m.peak(:) > 0.95), warning('Near full scale: turn the amplifier down.'); end
    if any(m.peak(2,:) < 0.01), warning('Very small UMIK signal: a cable still pulled? mic on?'); end
else
    if any(m.clip > 0), warning('Samples on the +-10 V rail: data not usable.'); end
    if m.k_amp == 2, fprintf('AI0 sits on a DC offset: V_amp = 2*AI0 used (as in Lab D).\n'); end
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

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
