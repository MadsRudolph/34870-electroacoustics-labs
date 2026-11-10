function m = measure_zinf(tag, kind, varargin)
% MEASURE_ZINF  One measurement at the Zi/Nfield station (Lab D setup), saved at once.
%
%   m = measure_zinf(tag, kind, Name, Value, ...)
%
%   tag   short file name, e.g. 'board', 'woofer_L160', 'nf_cone_L160'
%   kind  'board'      impedance at the passive board input (amp ch. 2 load), 20 Hz - 24 kHz
%         'woofer'     woofer impedance in its box, 1 Hz - 10 kHz
%         'nearfield'  microphone on AI1 via the Nexus, series resistor SHORTED, 1 Hz - 10 kHz
%
%   Name/Value (optional):
%     'R'            series resistor measured with the multimeter (ohm). REQUIRED for
%                    impedance: Lab D went wrong because R_E was typed instead of 32.9.
%     'Nav'          periods averaged (1 for impedance, 4 for near field)
%     'note'         free text (vent setting, mic position, which leads are off ...)
%     'NexusVperPa'  Nexus output setting (default 1 V/Pa)
%     'k'            true V_amp = k*AI0; 'auto' (default) decides from AI0's DC offset
%     'datadir'      default ../data      'plot'  default true
%
%   Uses the Lab D course routine meas_mag_spec2_LabD (Lab D/matlab/course in this
%   repo). Saves ../data/zinf_<tag>.mat with the raw spectra, time signals, the
%   derived Z or H, project_dims and a timestamp; never overwrites (_2, _3 ...).

p = inputParser;
p.addParameter('R', NaN);
p.addParameter('Nav', []);
p.addParameter('note', '');
p.addParameter('NexusVperPa', 1);
p.addParameter('k', 'auto');
p.addParameter('datadir', '');
p.addParameter('plot', true);
p.parse(varargin{:});
o = p.Results;

here = fileparts(mfilename('fullpath'));
if ~exist('meas_mag_spec2_LabD', 'file')
    addpath(fullfile(here, '..', '..', '..', '..', 'Lab D', 'matlab', 'course'));
end
datadir = o.datadir;
if isempty(datadir), datadir = fullfile(here, '..', 'data'); end
if ~exist(datadir, 'dir'), mkdir(datadir); end

switch kind
    case 'board',     f1 = 20; f2 = 24000; Nav = 1;
    case 'woofer',    f1 = 1;  f2 = 10000; Nav = 1;
    case 'nearfield', f1 = 1;  f2 = 10000; Nav = 4;
    otherwise, error('kind must be board, woofer or nearfield');
end
if ~strcmp(kind, 'nearfield') && ~(o.R > 20 && o.R < 50)
    error('Give the measured series resistor, e.g. ''R'', 32.9 (got %g).', o.R);
end
if ~isempty(o.Nav), Nav = o.Nav; end
n_oct = 48; fres = 0.125;

[fn, specn, f, spec, ch] = meas_mag_spec2_LabD(f1, f2, n_oct, fres, Nav);

r = zinf_calc(specn, ch, kind, o.R, o.NexusVperPa, o.k);
m = struct('tag', tag, 'kind', kind, 'f1', f1, 'f2', f2, 'n_oct', n_oct, ...
    'fres', fres, 'Nav', Nav, 'R', o.R, 'note', o.note, ...
    'NexusVperPa', o.NexusVperPa, 'k_amp', r.k, 'dc_AI0', r.dc_AI0, 'clip', r.clip, ...
    'time', datetime('now'), 'dims', project_dims(), ...
    'fn', fn(:), 'specn', specn, 'f', f(:), 'spec', spec, 'ch', ch);
m.rms = sqrt(mean(ch.^2));
m.peak = max(abs(ch));
if isfield(r, 'Z'), m.Z = r.Z; else, m.H = r.H; end

file = fullfile(datadir, ['zinf_' tag '.mat']);
n = 2;
while exist(file, 'file')
    file = fullfile(datadir, sprintf('zinf_%s_%d.mat', tag, n)); n = n + 1;
end
save(file, '-struct', 'm');
fprintf('\nSaved %s\n', file);
fprintf('rms AI0 %.3f V, AI1 %.3f V | peak %.2f / %.2f V | AI0 DC %.2f V -> k = %d\n', ...
    m.rms, m.peak, m.dc_AI0, m.k_amp);
if any(m.clip > 0)
    warning('%.1f %% / %.1f %% of the samples sit on the +-10 V rail: data not usable. Turn down or ask the TA.', 100*m.clip);
end
if m.k_amp == 2
    fprintf('AI0 is on a DC offset (as in Lab D): V_amp = 2*AI0 used. Check |Z| at low f against the multimeter.\n');
end
compare_zinf(m, 'plot', o.plot);
end
