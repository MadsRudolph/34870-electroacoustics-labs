function m = measure_project(tag, angle_deg, states, varargin)
% MEASURE_PROJECT  One phase-coherent run of the built System D, saved the moment it is taken.
%
%   m = measure_project(tag, angle_deg, states, Name, Value, ...)
%
%   tag        short file name, e.g. 'R1_split_0', 'R3_flip_0'
%   angle_deg  horizontal angle of the system in degrees (0 or 30; stored,
%              and picks the model curve: 0 -> expected_on, 30 -> expected_off30)
%   states     cell array of 1 to 3 switch states, measured in ONE run
%              (the course routine plays beeps between them; use the ~30 s
%              to switch). Names, matching model_curves.py:
%                'woofer'  Out 2 muted in the MiniDSP app
%                'midtw'   Out 1 muted (midrange + tweeter through the board)
%                'mid'     Out 1 muted, tweeter lead unplugged at the board
%                'tw'      Out 1 muted, midrange lead unplugged at the board
%                'all'     everything on, normal polarity
%                'flipW'   everything on, Out 1 'Invert' ticked in the app
%                'flipT'   everything on, tweeter + and - swapped at the board
%              Only states inside the same run share a phase reference
%              (the UMIK is a separate USB clock): compare phases within a
%              run, never across runs.
%
%   Name/Value (all optional):
%     'UmikSN'  UMIK serial, default from project_dims ('708-0332' in Lab E)
%     'Nav'     periods to average (default 64, as Lab E part 2)
%     'n_oct'   tones per octave (default 48, same grid as the Lab E data)
%     'note'    free text
%     'datadir' where to save (default lab-day/data)
%     'plot'    true/false, default true (measured vs. model, level-matched)
%
% Saves lab-day/data/project_<tag>.mat with everything the course routine returns
% (fn, specn, f, spec, ch), H(:,k) = specn(:,2,k)./specn(:,1,k) (p per volt at
% the sound card line-out, as in Lab E), the states, a timestamp, the
% hand-measured values from project_dims.m, and a snapshot of the design
% (design.json and the two MiniDSP texts) so the file says what was built.
% Never overwrites: a repeated tag gets _2, _3 ...

p = inputParser;
p.addParameter('UmikSN', '');
p.addParameter('Nav', 64);
p.addParameter('n_oct', 48);
p.addParameter('note', '');
p.addParameter('datadir', '');
p.addParameter('plot', true);
p.parse(varargin{:});
o = p.Results;

if ischar(states) || isstring(states), states = cellstr(states); end
valid = {'woofer', 'midtw', 'mid', 'tw', 'all', 'flipW', 'flipT'};
assert(numel(states) >= 1 && numel(states) <= 3, ...
    'The course routine does 1 to 3 measurements per run (Nmeas <= 3).');
bad = setdiff(states, valid);
assert(isempty(bad), 'Unknown state(s): %s. Use: %s', strjoin(bad, ', '), strjoin(valid, ', '));

L = labpaths();                         % kit/core/labpaths.m: every folder in one place
if isempty(which('project_dims')), addpath(L.manual); end
if isempty(which('meas_mag_spec2_SoundCard_LabE')), addpath(L.labEcourse); end
datadir = L.data;
if ~isempty(o.datadir), datadir = o.datadir; end
if ~exist(datadir, 'dir'), mkdir(datadir); end

dims = project_dims();
UmikSN = o.UmikSN;
if isempty(UmikSN), UmikSN = dims.UmikSN; end
Nmeas = numel(states);
f1 = 50; f2 = 20000; fres = 1;

if Nmeas > 1
    fprintf('\n%d states in one run, in this order:\n', Nmeas);
    for k = 1:Nmeas, fprintf('   %d. %s\n', k, describe(states{k})); end
    fprintf('Switch during each ~30 s of beeps.\n');
else
    fprintf('\nState: %s\n', describe(states{1}));
end
fprintf('Measuring about %.0f s ...\n', Nmeas*(o.Nav+1)/fres + (Nmeas-1)*30);

[fn, specn, f, spec, ch] = meas_mag_spec2_SoundCard_LabE(f1, f2, o.n_oct, fres, o.Nav, ...
    UmikSN, 0, Nmeas);

m = struct('tag', tag, 'angle_deg', angle_deg, 'states', {states}, ...
    'f1', f1, 'f2', f2, 'n_oct', o.n_oct, 'fres', fres, 'Nav', o.Nav, 'Nmeas', Nmeas, ...
    'UmikSN', UmikSN, 'IncAngle', 0, 'note', o.note, 'time', datetime('now'), ...
    'fn', fn(:), 'specn', specn, 'f', f(:), 'spec', spec, 'ch', ch, 'dims', dims);
m.H = reshape(specn(:,2,:) ./ specn(:,1,:), numel(fn), Nmeas);   % Pa per volt
m.peak = reshape(max(abs(ch), [], 1), 2, Nmeas);                  % line-in, UMIK
m.design = snapshot(L.final);

file = fullfile(datadir, ['project_' tag '.mat']);
k = 2;
while exist(file, 'file')
    file = fullfile(datadir, sprintf('project_%s_%d.mat', tag, k));
    k = k + 1;
end
save(file, '-struct', 'm');
fprintf('\nSaved %s\n', file);
for k = 1:Nmeas
    fprintf('  %-7s peak: line-in %.2f, UMIK %.2f\n', states{k}, m.peak(1,k), m.peak(2,k));
end
if any(m.peak(:) > 0.95)
    warning('A time signal is near full scale (1): turn the amplifier or the MiniDSP input down.');
end
if any(m.peak(2,:) < 0.01)
    warning('The UMIK signal is very small: check the mic and the mutes, turn the amplifier up.');
end
if o.plot
    compare_project(m);                 % numbers + quick overlay
    [~, stem] = fileparts(file);
    mp = m; mp.tag = erase(stem, 'project_');
    plot_project(mp, 'save', isempty(o.datadir));   % saved: ../figures/<tag>.png
end
end

function s = describe(state)
switch state
    case 'woofer', s = 'woofer only    (mid/tw silent: Out 2 muted OR its amp cable pulled)';
    case 'midtw',  s = 'mid + tweeter  (woofer silent: Out 1 muted OR its amp cable pulled)';
    case 'mid',    s = 'midrange only  (woofer silent, TWEETER lead off at the board)';
    case 'tw',     s = 'tweeter only   (woofer silent, MIDRANGE lead off at the board)';
    case 'all',    s = 'all three      (no mutes, normal polarity)';
    case 'flipW',  s = 'woofer inverted (Out 1 INVERT ticked)';
    case 'flipT',  s = 'tweeter swapped (+/- swapped at the board)';
end
end

function d = snapshot(fd)
% fd = the 'Final design' folder
d = struct();
d.design_json = readtext(fullfile(fd, 'design', 'design.json'));
d.minidsp_out1 = readtext(fullfile(fd, 'data', 'dsp', 'MiniDSP_woofer_out1.txt'));
d.minidsp_out2 = readtext(fullfile(fd, 'data', 'dsp', 'MiniDSP_midtw_out2.txt'));
end

function t = readtext(file)
if exist(file, 'file'), t = fileread(file); else, t = ''; end
end
