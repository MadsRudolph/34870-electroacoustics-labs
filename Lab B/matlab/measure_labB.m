function out = measure_labB(tag, UmikSN, note)
% MEASURE_LABB  One Lab B measurement with the course routine, saved right away.
%
%   measure_labB('nomockup', '708-0335')            reference, NO mock-up in the chamber
%   measure_labB('ang000',   '708-0335')            mock-up at 0 deg
%   measure_labB('ang045',   '708-0335', 'second try, amp at 10 o''clock')
%   measure_labB('dist100cm','708-0335')            Part 0: free-field check, mic 100 cm from the speaker
%
% Writes data/labB_<tag>.mat (never overwrites: adds _2, _3, ...) with everything the course
% function returns plus the settings, and draws a quick check plot: the transfer function
% H = mic/loudspeaker signal, and signal vs. noise floor. Copy this file and the course files
% (matlab/course/) to the lab PC; take the data/ folder home on the USB stick.
if nargin < 3, note = ''; end
P = struct('f1', 50, 'f2', 10000, 'n_oct', 24, 'fres', 1, 'Nav', 32, 'IncAngle', 90);   % from the lab sheet
addpath(fullfile(fileparts(mfilename('fullpath')), 'course'));
[fn, specn, f, spec, ch] = meas_mag_spec2_SoundCard_LabB(P.f1, P.f2, P.n_oct, P.fres, P.Nav, UmikSN, P.IncAngle);
H = specn(:, 2) ./ specn(:, 1);

d = fullfile(fileparts(mfilename('fullpath')), '..', 'data'); if ~exist(d, 'dir'), mkdir(d); end
file = fullfile(d, ['labB_' tag '.mat']); k = 1;
while exist(file, 'file'), k = k + 1; file = fullfile(d, sprintf('labB_%s_%d.mat', tag, k)); end
meta = struct('tag', tag, 'UmikSN', UmikSN, 'note', note, 'time', datestr(now, 31), 'params', P); %#ok<TNOW1,DATST>
save(file, 'fn', 'specn', 'f', 'spec', 'ch', 'H', 'meta');
fprintf('saved %s\n', file);

% ---- quick check: is the signal well above the noise? (lab sheet: "well over noise")
isSig = ismember(round(f(:)), round(fn(:)));
band = f(:) >= P.f1 & f(:) <= P.f2;
figure(30); clf
subplot(2, 1, 1); semilogx(fn, 20*log10(abs(H)), 'b-'); grid on
title(['H = mic / loudspeaker signal   [' strrep(tag, '_', '\_') ']']); ylabel('dB'); xlim([P.f1 P.f2])
subplot(2, 1, 2); semilogx(f(band & ~isSig), 20*log10(abs(spec(band & ~isSig, 2)) + eps), '.', 'Color', [.7 .7 .7]); hold on
semilogx(fn, 20*log10(abs(specn(:, 2))), 'r-', 'LineWidth', 1.2); grid on
legend('between the tones = noise + distortion', 'at the signal tones', 'Location', 'southwest')
title('microphone channel: signal vs. noise floor (want > 30 dB of clearance)'); xlabel('Frequency [Hz]'); ylabel('dB'); xlim([P.f1 P.f2])
snr = median(20*log10(abs(specn(:, 2)))) - median(20*log10(abs(spec(band & ~isSig, 2)) + eps));
fprintf('median signal-to-noise on the microphone channel: %.0f dB\n', snr);
if snr < 30, warning('Low signal-to-noise: turn the amplifier up a little and measure again.'); end
if nargout, out = struct('fn', fn, 'H', H, 'file', file); end
end
