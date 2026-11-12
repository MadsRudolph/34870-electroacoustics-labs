function m = measure_labD(tag, kind, varargin)
% MEASURE_LABD  One Lab D measurement, saved to disk the moment it is taken.
%
%   m = measure_labD(tag, kind, Name, Value, ...)
%
%   tag   short name for the file, e.g. 'tweeter', 'woofer_free', 'vent_L120'
%   kind  'tweeter' | 'midrange' | 'woofer'   -> impedance with the series R
%         'nearfield'                          -> microphone on AI1, R shorted
%
%   Name/Value (all optional):
%     'R'      measured series resistor in ohm (default 33). Use the
%              multimeter value, not the colour code (5 % tolerance).
%     'Nav'    periods to average (default 1 for impedance, 4 for near field)
%     'note'   free text stored with the data (vent length, mic position ...)
%     'NexusVperPa'  Nexus output setting for near field (default 1 V/Pa)
%
%   Saves  ../data/labD_<tag>.mat  with everything the course routine returns
%   (fn, specn, f, spec, ch), the parameters, the derived Z or H and a
%   timestamp, then plots the result. Nothing is ever overwritten: if the
%   file exists, a suffix _2, _3 ... is added.
%
%   Parameters follow the brief (section 2a/3):
%     tweeter   f1 = 100, f2 = 24000
%     midrange  f1 = 20,  f2 = 20000
%     woofer    f1 = 1,   f2 = 10000   (also used for the near field)
%     n_oct = 48, fres = 0.125

p = inputParser;
p.addParameter('R', 33);
p.addParameter('Nav', []);
p.addParameter('note', '');
p.addParameter('NexusVperPa', 1);
p.parse(varargin{:});
o = p.Results;

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'course'));
datadir = fullfile(here, '..', 'data');
if ~exist(datadir, 'dir'), mkdir(datadir); end

switch kind
    case 'tweeter',   f1 = 100; f2 = 24000; Nav = 1;
    case 'midrange',  f1 = 20;  f2 = 20000; Nav = 1;
    case 'woofer',    f1 = 1;   f2 = 10000; Nav = 1;
    case 'nearfield', f1 = 1;   f2 = 10000; Nav = 4;
    otherwise, error('kind must be tweeter, midrange, woofer or nearfield');
end
if ~isempty(o.Nav), Nav = o.Nav; end
n_oct = 48;
fres  = 0.125;

[fn, specn, f, spec, ch] = meas_mag_spec2_LabD(f1, f2, n_oct, fres, Nav);

m = struct('tag', tag, 'kind', kind, 'f1', f1, 'f2', f2, 'n_oct', n_oct, ...
    'fres', fres, 'Nav', Nav, 'R', o.R, 'note', o.note, ...
    'NexusVperPa', o.NexusVperPa, 'time', datetime('now'), ...
    'fn', fn(:), 'specn', specn, 'f', f(:), 'spec', spec, 'ch', ch);
m.rms = sqrt(mean(ch.^2));          % [Vamp  Vloud]  or  [Vamp  Vmic]
m.peak = max(abs(ch));

if strcmp(kind, 'nearfield')
    % AI0 = amplifier = loudspeaker voltage (R shorted), AI1 = Nexus output
    m.H = (specn(:,2) / o.NexusVperPa) ./ specn(:,1);   % Pa per volt
else
    % AI0 = Vamp, AI1 = Vloud;  Z_L = R (Vl/Va) / (1 - Vl/Va)
    G = specn(:,2) ./ specn(:,1);
    m.Z = o.R * G ./ (1 - G);
end

file = fullfile(datadir, ['labD_' tag '.mat']);
k = 2;
while exist(file, 'file')
    file = fullfile(datadir, sprintf('labD_%s_%d.mat', tag, k));
    k = k + 1;
end
save(file, '-struct', 'm');
fprintf('\nSaved %s\n', file);
fprintf('rms: AI0 = %.3f V, AI1 = %.3f V   peak: %.2f / %.2f V\n', m.rms, m.peak);

if any(m.peak > 9.5)
    warning('An input is near the +/-10 V limit: turn the amplifier down.');
end

figure('Name', tag);
if strcmp(kind, 'nearfield')
    subplot(2,1,1); semilogx(m.fn, 20*log10(abs(m.H))); grid on
    ylabel('|p/V| (dB re 1 Pa/V)'); title(['Near field: ' tag], 'Interpreter', 'none')
    subplot(2,1,2); semilogx(m.fn, angle(m.H)*180/pi); grid on
    ylabel('phase (deg)'); xlabel('frequency (Hz)')
else
    subplot(2,1,1); semilogx(m.fn, abs(m.Z)); grid on
    ylabel('|Z| (\Omega)'); title(['Impedance: ' tag], 'Interpreter', 'none')
    subplot(2,1,2); semilogx(m.fn, angle(m.Z)*180/pi); grid on
    ylabel('phase (deg)'); xlabel('frequency (Hz)')
    % quick look: the low-frequency end should sit on R_E
    fprintf('|Z| at the lowest tone (%.2f Hz): %.2f ohm\n', m.fn(1), abs(m.Z(1)));
    [Zmax, i] = max(abs(m.Z(m.fn < 1000)));
    fprintf('Largest |Z| below 1 kHz: %.2f ohm at %.1f Hz\n', Zmax, m.fn(i));
end
end
