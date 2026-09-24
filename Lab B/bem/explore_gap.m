% EXPLORE_GAP  What does the microphone see when it sits a distance z in front of the mock-up face?
%
% The BEM field point [r_FP z_FP] is in the cylinder's own coordinates: the face is at z = 0 and
% z_FP is the gap in front of it, r_FP the distance off the axis. So "move the UMIK away from the
% face" = increase z_FP, at any incidence angle.  Each gap costs one full BEM solve (~13 s), so
% keep the list short.  The measured curve at the same angle is drawn on top for comparison.
%
% Run with F5, or section by section (Ctrl+Enter) after changing the settings.

%% settings: change these
gaps   = [0 0.01 0.02 0.03 0.05];   % [m] distance from the face centre to the microphone
angle  = 0;                         % [deg] mock-up angle (measured: 0 15 30 45 60 75 90)
offaxis = 0;                        % [m] r_FP: 0 = on the axis
CylEnd = 'Round';                   % 'Round' or 'Flat' back end

%% BEM for every gap
here = fileparts(mfilename('fullpath'));
old = cd(fullfile(here, 'package'));          % CylinderPlaneWave only runs from inside its folder
P = [];
for k = 1:numel(gaps)
    tic
    [fr, pc, pfp] = CylinderPlaneWave(angle*pi/180, CylEnd, 'no', [offaxis gaps(k)]);
    close all
    if gaps(k) == 0 && offaxis == 0, P(k, :) = pc; else, P(k, :) = pfp; end %#ok<SAGROW>   % a field point ON the surface is singular: use the face-centre pressure
    fprintf('gap %4.1f cm: %.0f s\n', gaps(k)*100, toc);
end
cd(old);

%% plot, with the measured curve at this angle
dataDir = fullfile(here, '..', 'data');
figure(10); clf; try, theme(gcf, 'light'); catch, set(gcf, 'Color', 'w'); end
hold on
mfile = fullfile(dataDir, sprintf('labB_ang%03d.mat', angle));
if exist(mfile, 'file')
    m = load(mfile); ref = load(fullfile(dataDir, 'labB_nomockup.mat'));
    semilogx(m.fn, 20*log10(abs(m.H ./ ref.H)), 'k-', 'LineWidth', 2.2, 'DisplayName', sprintf('measured, %d°', angle));
end
col = parula(numel(gaps) + 1);
for k = 1:numel(gaps)
    semilogx(fr, 20*log10(abs(P(k, :))), '-', 'Color', col(k, :), 'LineWidth', 1.3, ...
        'DisplayName', sprintf('BEM, %.1f cm in front', gaps(k)*100));
end
set(gca, 'XScale', 'log'); grid on; xlim([100 5400]); ylim([-25 15])
xlabel('Frequency [Hz]'); ylabel('dB re incident / no mock-up')
title(sprintf('%s end, %d°: pressure at a microphone z in front of the face', CylEnd, angle))
legend('Location', 'southwest')

%% numbers per gap: the peak below 2 kHz and the deepest dip above it (BEM stops at 5382 Hz)
fprintf('\n%-8s %-22s %-22s\n', 'gap', 'peak below 2 kHz', 'deepest dip above');
for k = 1:numel(gaps)
    d = 20*log10(abs(P(k, :))); lo = fr < 2000; hi = ~lo; flo = fr(lo); fhi = fr(hi);
    [pv, pi] = max(d(lo)); [dv, di] = min(d(hi));
    fprintf('%4.1f cm  %5.1f dB at %5.0f Hz     %6.1f dB at %5.0f Hz\n', gaps(k)*100, pv, flo(pi), dv, fhi(di));
end
