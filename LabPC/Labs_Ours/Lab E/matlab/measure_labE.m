function m = measure_labE(tag, part, angle_deg, varargin)
% MEASURE_LABE  One Lab E measurement, saved to disk the moment it is taken.
%
%   m = measure_labE(tag, part, angle_deg, Name, Value, ...)
%
%   tag        short name for the file, e.g. 'box_0', 'circle_30', 'iec_60',
%              'system_0'
%   part       'baffle'  part 1: the 3" driver (small box / circular / IEC)
%              'system'  part 2: the project system, all three units in one
%                        run through the switchboard (Nmeas = 3)
%   angle_deg  horizontal angle of the loudspeaker in degrees (stored only)
%
%   Name/Value (all optional):
%     'UmikSN'    UMIK serial number as a string (default '708-0332',
%                 the one Group 10 used in Lab B: check the label!)
%     'IncAngle'  incidence on the UMIK: 0 = pointing at the speaker
%                 (default 0, as in the brief)
%     'Nav'       periods to average (default 16 baffle, 64 system)
%     'n_oct'     tones per octave (default 24 baffle, 48 system)
%     'Nmeas'     consecutive measurements (default 1 baffle, 3 system)
%     'units'     names of the Nmeas units in switch order
%                 (default {'woofer','midrange','tweeter'} for 'system')
%     'note'      free text stored with the data
%
%   Parameters follow the brief: f1 = 50 Hz, f2 = 20 kHz, fres = 1 Hz.
%
%   Saves ../data/labE_<tag>.mat with everything the course routine returns
%   (fn, specn, f, spec, ch), the parameters, H = p/V for every measurement
%   (H(:,k) = specn(:,2,k)./specn(:,1,k)) and a timestamp, then plots |H|
%   and the phase. Never overwrites: a repeated tag gets _2, _3 ...

p = inputParser;
p.addParameter('UmikSN', '708-0332');
p.addParameter('IncAngle', 0);
p.addParameter('Nav', []);
p.addParameter('n_oct', []);
p.addParameter('Nmeas', []);
p.addParameter('units', {});
p.addParameter('note', '');
p.addParameter('datadir', '');
p.parse(varargin{:});
o = p.Results;

here = fileparts(mfilename('fullpath'));
if isempty(which('meas_mag_spec2_SoundCard_LabE')), addpath(fullfile(here, 'course')); end
datadir = fullfile(here, '..', 'data');
if ~isempty(o.datadir), datadir = o.datadir; end
if ~exist(datadir, 'dir'), mkdir(datadir); end

switch part
    case 'baffle', Nav = 16; n_oct = 24; Nmeas = 1; units = {'3in driver'};
    case 'system', Nav = 64; n_oct = 48; Nmeas = 3; units = {'woofer', 'midrange', 'tweeter'};
    otherwise, error('part must be ''baffle'' or ''system''');
end
if ~isempty(o.Nav),   Nav = o.Nav; end
if ~isempty(o.n_oct), n_oct = o.n_oct; end
if ~isempty(o.Nmeas), Nmeas = o.Nmeas; end
if ~isempty(o.units), units = o.units; end
if numel(units) ~= Nmeas
    units = arrayfun(@(k) sprintf('unit %d', k), 1:Nmeas, 'UniformOutput', false);
end
f1 = 50; f2 = 20000; fres = 1;

if Nmeas > 1
    fprintf(['\n%d units in one run. Switch order: %s.\n' ...
        'Switch to the next unit during each ~30 s of beeps.\n'], Nmeas, strjoin(units, ' -> '));
end
fprintf('Measuring about %.0f s ...\n', Nmeas*(Nav+1)/fres + (Nmeas-1)*30);

[fn, specn, f, spec, ch] = meas_mag_spec2_SoundCard_LabE(f1, f2, n_oct, fres, Nav, ...
    o.UmikSN, o.IncAngle, Nmeas);

m = struct('tag', tag, 'part', part, 'angle_deg', angle_deg, 'units', {units}, ...
    'f1', f1, 'f2', f2, 'n_oct', n_oct, 'fres', fres, 'Nav', Nav, 'Nmeas', Nmeas, ...
    'UmikSN', o.UmikSN, 'IncAngle', o.IncAngle, 'note', o.note, ...
    'time', datetime('now'), 'fn', fn(:), 'specn', specn, 'f', f(:), ...
    'spec', spec, 'ch', ch);
m.H = reshape(specn(:,2,:) ./ specn(:,1,:), numel(fn), Nmeas);   % Pa per volt
m.peak = reshape(max(abs(ch), [], 1), 2, Nmeas);  % 2 x Nmeas: line-in, UMIK

file = fullfile(datadir, ['labE_' tag '.mat']);
k = 2;
while exist(file, 'file')
    file = fullfile(datadir, sprintf('labE_%s_%d.mat', tag, k));
    k = k + 1;
end
save(file, '-struct', 'm');
fprintf('\nSaved %s\n', file);
for k = 1:Nmeas
    fprintf('  %-10s peak: line-in %.2f, UMIK %.2f\n', units{k}, m.peak(1,k), m.peak(2,k));
end
if any(m.peak(:) > 0.95)
    warning('A time signal is near full scale (1): turn the amplifier down.');
end
if any(m.peak(2,:) < 0.01)
    warning('The UMIK signal is very small: check the mic and turn the amplifier up.');
end

figure('Name', tag);
subplot(2,1,1)
semilogx(m.fn, 20*log10(abs(m.H)), 'LineWidth', 1.1); grid on
xlim([f1 f2]); ylabel('|p/V| (dB re 1 Pa/V)')
title(sprintf('%s, %g deg', tag, angle_deg), 'Interpreter', 'none')
legend(units, 'Location', 'southwest')
subplot(2,1,2)
semilogx(m.fn, angle(m.H)*180/pi, 'LineWidth', 1.1); grid on
xlim([f1 f2]); ylabel('phase (deg)'); xlabel('frequency (Hz)')
end
