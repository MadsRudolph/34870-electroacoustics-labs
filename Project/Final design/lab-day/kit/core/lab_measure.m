function [m, file, warn] = lab_measure(what, S, varargin)
% LAB_MEASURE  One run: call the course routine, save the file, return the run. No plots,
%   no dialogs: used by both the 'lab' command and labgui.
%
%   [m, file, warn] = lab_measure(what, S, Name, Value, ...)
%
%   what     'P', 'P1', {'S1','S3'} ... (see lab_steps)
%   S        settings (lab_settings / lab_setup), stored in the file as m.setup
%   Name/Value:
%     'datadir'      where to save (required in practice; default lab-day/data/<S.date>)
%     'Nav'          chamber periods to average (default 64)
%     'note'         free text stored with the run
%     'chamber_fun'  function handle with the signature of meas_mag_spec2_SoundCard_LabE
%     'zinf_fun'     function handle with the signature of meas_mag_spec2_LabD
%                    (both default to the course routines; labgui's demo mode passes stand-ins)
%     'demo'         true = the data are stand-in data (stored as m.demo)
%
%   file  = the saved .mat (never overwritten: a repeat gets _2, _3 ...)
%   warn  = cellstr of things to look at at once (clipping, small UMIK signal, AI0 offset)

p = inputParser;
p.addParameter('datadir', '');
p.addParameter('Nav', 64);
p.addParameter('note', '');
p.addParameter('chamber_fun', []);
p.addParameter('zinf_fun', []);
p.addParameter('demo', false);
p.parse(varargin{:});
o = p.Results;

L = labpaths();
if isempty(which('zinf_calc')), addpath(L.manualcore); end
[st, ids, label] = lab_steps(what);
datadir = o.datadir;
if isempty(datadir), datadir = fullfile(L.data, S.date); end
station = st(1).station;

m = struct('label', label, 'ids', {ids}, 'station', station, 'angle', st(1).angle, ...
    'dsp', st(1).dsp, 'setup', S, 'note', o.note, 'time', datetime('now'), 'demo', logical(o.demo));
if strcmp(station, 'chamber')
    assert(~isempty(S.UmikSN), 'Set the UMIK serial number (UmikSN) first.');
    fun = o.chamber_fun;
    if isempty(fun)
        if isempty(which('meas_mag_spec2_SoundCard_LabE')), addpath(L.labEcourse); end
        fun = @meas_mag_spec2_SoundCard_LabE;
        back = run_where_beeps_are(which('meas_mag_spec2_SoundCard_LabE')); %#ok<NASGU>
    end
    n = numel(st);
    [fn, specn, f, spec, ch] = fun(50, 20000, 48, 1, o.Nav, S.UmikSN, 0, n);
    m.fn = fn(:);
    m.H = reshape(specn(:,2,:) ./ specn(:,1,:), numel(fn), n);
    m.peak = reshape(max(abs(ch), [], 1), 2, n);
    m.Nav = o.Nav;
else
    kind = st.model;
    nf = startsWith(kind, 'nf');
    if ~nf, assert(S.R_series > 20 && S.R_series < 50, ...
            'Set R_series to the multimeter value of the series resistor (about 32.9 ohm).'); end
    fun = o.zinf_fun;
    if isempty(fun)
        if isempty(which('meas_mag_spec2_LabD')), addpath(L.labDcourse); end
        fun = @meas_mag_spec2_LabD;
    end
    if nf || strcmp(kind, 'woofer'), f1 = 1; f2 = 10000; else, f1 = 20; f2 = 24000; end
    Nav = 1 + 3*nf;
    [fn, specn, f, spec, ch] = fun(f1, f2, 48, 0.125, Nav);
    if nf, how = 'nearfield'; else, how = 'impedance'; end
    r = zinf_calc(specn, ch, how, S.R_series, S.NexusVperPa, 'auto');
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
warn = lab_flags(m);
end

function back = run_where_beeps_are(routine)
% The course routine reads 'beeps.wav' from the CURRENT folder. If it is not here but next
% to the routine, run from there (and come back afterwards, also after an error/Ctrl+C).
back = [];
if hasbeeps(pwd) || isempty(routine), return; end
rdir = fileparts(routine);
if hasbeeps(rdir)
    old = cd(rdir);
    back = onCleanup(@() cd(old));
end
end

function y = hasbeeps(d)
x = dir(d); y = any(strcmpi({x.name}, 'beeps.wav'));
end
