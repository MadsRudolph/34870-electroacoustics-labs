function [m, file, W] = lab_measure(what, S, datadir, varargin)
% LAB_MEASURE  One run: measure, save at once (never overwrites), list the warnings.
%   The engine behind both the command  lab  and the GUI  labgui. No dialogs, no plots.
%
%   [m, file, W] = lab_measure(what, S, datadir, 'Nav', 64, 'note', '', 'demo', [])
%
%   what     step id, run group or cell of ids (see lab_steps)
%   S        the session's settings (lab_setup / lab_settings): stored in the file
%   datadir  where to save: <datadir>/<label>.mat, a repeat gets _2, _3 ...
%   'demo'   [] = the real course routines. A struct (see lab_demo) = stand-ins that
%            "measure" the expected curves: no hardware, for rehearsing at home.
%   W(i)     level ('warn' | 'info'), msg, fix: what to tell the user straight away

p = inputParser;
p.addParameter('Nav', 64);
p.addParameter('note', '');
p.addParameter('demo', []);
p.parse(varargin{:});
o = p.Results;
L = labpaths;
demo = ~isempty(o.demo);
inreal = strncmp(datadir, L.data, numel(L.data));
assert(~(demo && inreal), 'lab:demo', 'Demo measurements may not be saved in the real data folder (%s).', L.data);

[st, ids, label] = lab_steps(what);
station = st(1).station;
W = struct('level', {}, 'msg', {}, 'fix', {});
m = struct('label', label, 'ids', {ids}, 'station', station, 'angle', st(1).angle, ...
    'dsp', st(1).dsp, 'setup', S, 'note', o.note, 'time', datetime('now'));
if demo, m.demo = true; end

if strcmp(station, 'chamber')
    n = numel(st);
    if demo
        [fn, specn, f, spec, ch] = lab_demo(st, S, o.demo, o.Nav);
    else
        if isempty(which('meas_mag_spec2_SoundCard_LabE')), addpath(L.labEcourse); end
        [fn, specn, f, spec, ch] = meas_mag_spec2_SoundCard_LabE(50, 20000, 48, 1, o.Nav, S.UmikSN, 0, n);
    end
    m.fn = fn(:);
    m.H = reshape(specn(:,2,:) ./ specn(:,1,:), numel(fn), n);
    m.peak = reshape(max(abs(ch), [], 1), 2, n);
    m.Nav = o.Nav;
else
    kind = st.model;
    nf = startsWith(kind, 'nf');
    if ~nf
        assert(S.R_series > 20 && S.R_series < 50, 'lab:Rseries', ...
            'Set R_series to the multimeter value of the series resistor (about 32.9): in the GUI Settings, or in lab_setup.m.');
    end
    if nf || strcmp(kind, 'woofer'), f1 = 1; f2 = 10000; else, f1 = 20; f2 = 24000; end
    Nav = 1 + 3*nf;
    if demo
        [fn, specn, f, spec, ch] = lab_demo(st, S, o.demo, Nav);
    else
        if isempty(which('meas_mag_spec2_LabD')), addpath(L.labDcourse); end
        [fn, specn, f, spec, ch] = meas_mag_spec2_LabD(f1, f2, 48, 0.125, Nav);
    end
    if nf, zk = 'nearfield'; else, zk = 'impedance'; end
    r = zinf_calc(specn, ch, zk, S.R_series, S.NexusVperPa, 'auto');
    m.fn = fn(:);
    if nf, m.H = r.H; else, m.Z = r.Z; end
    m.k_amp = r.k; m.dc_AI0 = r.dc_AI0; m.clip = r.clip; m.peak = max(abs(ch));
    m.Nav = Nav;
end
m.time = datetime('now');
m.specn = specn; m.spec = spec; m.f = f(:); m.ch = ch;

if ~exist(datadir, 'dir'), mkdir(datadir); end
file = fullfile(datadir, [label '.mat']); k = 2;
while exist(file, 'file'), file = fullfile(datadir, sprintf('%s_%d.mat', label, k)); k = k + 1; end
save(file, '-struct', 'm');
[~, m.file] = fileparts(file);

% ---- warnings that matter at once
if strcmp(station, 'chamber')
    if any(m.peak(:) > 0.95)
        W(end+1) = struct('level', 'warn', 'msg', sprintf('Near full scale (peak %.2f): the recording clips.', max(m.peak(:))), ...
            'fix', 'Turn the amplifier down a little (then EVERY run of the day must be redone), or lower the sound card output. Redo this run.');
    end
    if any(m.peak(2,:) < 0.01)
        q = find(m.peak(2,:) < 0.01);
        W(end+1) = struct('level', 'warn', 'msg', sprintf('Very small UMIK signal in %s (peak %.4f).', strjoin(ids(q), ', '), min(m.peak(2,:))), ...
            'fix', 'Is that unit switched ON on the switchboard? Is the amplifier on? Is the UMIK the recording device? Check, then redo this run.');
    end
else
    if any(m.clip > 0)
        W(end+1) = struct('level', 'warn', 'msg', sprintf('%.1f %% / %.1f %% of the samples sit on the +-10 V rail: data not usable.', 100*m.clip), ...
            'fix', 'Turn the amplifier down (or ask the TA) and redo this step.');
    end
    if m.k_amp == 2
        W(end+1) = struct('level', 'info', 'msg', sprintf('AI0 sits on a DC offset (%.1f V): V_amp = 2*AI0 used, as in Lab D.', m.dc_AI0), ...
            'fix', 'Nothing to do. Check that |Z| at low frequency matches the multimeter value.');
    end
end
end
