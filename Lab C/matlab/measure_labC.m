function out = measure_labC(tag, kind, Nav, note)
% MEASURE_LABC  One multitone measurement with the course routine (meas_mag_spec2), saved right away.
%
%   measure_labC('ref', 'system')              Part 1: AO0 -> AI0 and AO0 -> Nexus -> AI1   (fb = 1)
%   measure_labC('noise_4133', 'mic')          Part 3b: actuator supply OFF, Nav = 4         (fb = 200)
%   measure_labC('noise_4133_N64', 'mic', 64)  Part 3b: same with Nav = 64
%   measure_labC('resp_4133', 'mic')           Part 3c: actuator supply ON
%   measure_labC('resp_4134', 'mic')
%
% kind 'system' uses fb = 1, kind 'mic' uses fb = 200 (the brief's two parameter sets); everything
% else is f1 = 20, f2 = 60000, Amax = 1, n_oct = 6, fres = 1. Saves data/labC_<tag>.mat (never
% overwrites) with fn, specn, f, spec, H21 = specn(:,2)./specn(:,1) and the settings.
if nargin < 4, note = ''; end
if nargin < 3 || isempty(Nav), Nav = 4; end
P = struct('f1', 20, 'f2', 60000, 'Amax', 1, 'n_oct', 6, 'Nav', Nav, 'fb', 1, 'fres', 1);
if strcmpi(kind, 'mic'), P.fb = 200; end
addpath(fullfile(fileparts(mfilename('fullpath')), 'course'));
[fn, specn, f, spec] = meas_mag_spec2(P.f1, P.f2, P.Amax, P.n_oct, P.Nav, P.fb, P.fres);
H21 = specn(:, 2) ./ specn(:, 1);

d = fullfile(fileparts(mfilename('fullpath')), '..', 'data'); if ~exist(d, 'dir'), mkdir(d); end
file = fullfile(d, ['labC_' tag '.mat']); k = 1;
while exist(file, 'file'), k = k + 1; file = fullfile(d, sprintf('labC_%s_%d.mat', tag, k)); end
meta = struct('tag', tag, 'kind', kind, 'note', note, 'time', datestr(now, 31), 'params', P); %#ok<TNOW1,DATST>
save(file, 'fn', 'specn', 'f', 'spec', 'H21', 'meta'); fprintf('saved %s\n', file);

if strcmpi(kind, 'system')      % the two numbers the brief asks you to note down for Part 2
    for f0 = [250 1000]
        h = interp1(fn(:), H21, f0);
        fprintf('H_21_%d = %.5f   (|.| = %.5f, %.2f deg)\n', f0, abs(h), abs(h), angle(h)*180/pi);
    end
end
figure(31); clf
subplot(2, 1, 1); semilogx(fn, 20*log10(abs(H21))); grid on; ylabel('|H_{21}| [dB]'); title(strrep(tag, '_', '\_')); xlim([P.f1 P.f2])
subplot(2, 1, 2); semilogx(fn, unwrap(angle(H21))*180/pi); grid on; ylabel('phase [deg]'); xlabel('Frequency [Hz]'); xlim([P.f1 P.f2])
if nargout, out = struct('fn', fn, 'H21', H21, 'file', file); end
end
