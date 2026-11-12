%% Lab E: figures from the measured data (local, not for the shared repo)
% Part 1: the 3" driver on three mountings, diffrac.m for the circle and the
% IEC screen, IEC off-axis over on-axis against the piston directivity.
% Part 2: System D, the three units at 0 and 30 degrees, and the relative
% phase at 0 degrees after the compensation distance.
% Writes ../figures/labE_*.png and caches diffrac in ../results/.
%
%   matlab -batch plot_labE < /dev/null

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
addpath(fullfile(here, 'course'))
datadir = fullfile(here, '..', 'data');
figdir  = fullfile(here, '..', 'figures');  if ~exist(figdir, 'dir'), mkdir(figdir); end
resdir  = fullfile(here, '..', 'results');  if ~exist(resdir, 'dir'), mkdir(resdir); end
ld = @(tag) load(fullfile(datadir, ['labE_' tag '.mat']));
d  = labE_dims();
c  = 331.3*sqrt(1 + d.T_celsius/273.15);   % 343.2 m/s at 20 degC
fmax = 18000;                               % the UMIK channel jumps ~20 dB above 18.4 kHz
dBv = @(H) 20*log10(abs(H));
set(groot, 'defaultLineLineWidth', 1.3)

%% Circle formula: path difference, peaks and dips
a = d.circle_radius; r = d.r_mic_1;
Delta = a + sqrt(a^2 + r^2) - r;
f_pk = (2*(1:3) - 1)*c/(2*Delta);    % in phase: Delta = (2n-1) lambda/2
f_dp = (1:3)*c/Delta;                % cancel:   Delta = n lambda
fprintf('Circle: Delta = %.3f m, peaks %s Hz, dips %s Hz\n', Delta, mat2str(round(f_pk)), mat2str(round(f_dp)))

%% diffrac.m (Terai), cached: it opens a figure per angle and takes a while
cache = fullfile(resdir, 'labE_diffrac2.mat');
if exist(cache, 'file')
    load(cache)
else
    N = 200; th = linspace(0, 2*pi, N+1)';
    circ = [a*cos(th), a*sin(th)];
    % driver at (0,0): rectangle relative to the driver, seen from the mic
    x1 = -d.iec_driver(1); x2 = d.iec_size(1) - d.iec_driver(1);
    y1 = -d.iec_driver(2); y2 = d.iec_size(2) - d.iec_driver(2);
    rect = [x1 y1; x2 y1; x2 y2; x1 y2; x1 y1];
    as = d.diam_3in/2;
    [~, ~, fDc, Dc_pt] = diffrac(circ, r, [0 0; 30 0], 0.001, 48000);   close all
    [~, ~, ~,  Dc_ex] = diffrac(circ, r, [0 0; 30 0], as, 48000);      close all
    [~, ~, fDi, Di_pt] = diffrac(rect, r, [0 0; 15 0; 30 0; 60 0], 0.001, 48000); close all
    [~, ~, ~,  Di_ex] = diffrac(rect, r, [0 0; 15 0; 30 0; 60 0], as, 48000);    close all
    save(cache, 'fDc', 'fDi', 'Dc_pt', 'Dc_ex', 'Di_pt', 'Di_ex', 'rect', 'circ', 'as')
end

box0 = ld('box_0'); box30 = ld('box_30');
ci0 = ld('circle_0'); ci30 = ld('circle_30');
ie = arrayfun(@(t) ld(sprintf('iec_%d', t)), [0 15 30 60]);
f = ci0.fn; k = f <= fmax;

%% Figure 1: three mountings at 0 and 30 degrees
fig = figure('Position', [100 100 1000 760], 'Color', 'w'); try, theme(fig, 'light'); end
for s = 1:2
    subplot(2,1,s)
    if s == 1, M = {box0, ci0, ie(1)}; ang = 0; else, M = {box30, ci30, ie(3)}; ang = 30; end
    for j = 1:3, semilogx(f(k), dBv(M{j}.H(k))); hold on, end
    if s == 1
        for n = 1:2
            xline(f_pk(n), ':', sprintf('peak %.0f Hz', f_pk(n)), 'Color', [0.4 0.4 0.4]);
            xline(f_dp(n), ':', sprintf('dip %.0f Hz', f_dp(n)), 'Color', [0.4 0.4 0.4]);
        end
    end
    grid on; xlim([50 fmax]); ylim([-35 15])
    xlabel('Frequency (Hz)'); ylabel('|H| (dB re 1 Pa/V)')
    title(sprintf('3" driver at %.2f m, %d°: small box, circular screen (a = %.2f m), IEC screen (off-centre)', r, ang, a))
    legend('small box', 'circular screen, centred', 'IEC screen, off-centre', 'Location', 'south')
end
exportgraphics(fig, fullfile(figdir, 'labE_mountings.png'), 'Resolution', 200);

%% Figure 2: circle against diffrac; circle minus IEC (driver cancels)
% diffrac is dB re free field; the measured curve carries the driver's own
% response, so it is shifted to the model's mean over 300 Hz - 5 kHz.
band = f >= 300 & f <= 5000;
Dci = @(D, j) interp1(fDc, D(:, j), f);   % circle on the measured grid
Dii = @(D, j) interp1(fDi, D(:, j), f);   % IEC rectangle
fig = figure('Position', [100 100 1000 900], 'Color', 'w'); try, theme(fig, 'light'); end
for s = 1:2
    subplot(3,1,s)
    Mh = {ci0, ci30}; Mh = Mh{s};
    m = dBv(Mh.H); dpt = Dci(Dc_pt, s); dex = Dci(Dc_ex, s);
    off = mean(dex(band)) - mean(m(band));
    semilogx(f(k), m(k) + off, 'k'); hold on
    semilogx(fDc, Dc_pt(:, s), 'Color', [0.85 0.33 0.10]);
    semilogx(fDc, Dc_ex(:, s), 'Color', [0.00 0.45 0.74]);
    grid on; xlim([50 fmax]); ylim([-20 15])
    ylabel('dB re free field'); title(sprintf('Circular screen, %d°: measured (shifted %+.1f dB) and diffrac.m', 30*(s-1), off))
    legend('measured', 'diffrac, point source', sprintf('diffrac, piston a_s = %.0f mm', 1e3*as), 'Location', 'south')
end
subplot(3,1,3)
semilogx(f(k), dBv(ci0.H(k)) - dBv(ie(1).H(k)), 'k'); hold on
dd = Dci(Dc_ex, 1) - Dii(Di_ex, 1);
semilogx(f(k), dd(k), 'Color', [0.00 0.45 0.74]);
grid on; xlim([50 fmax]); ylim([-15 12])
xlabel('Frequency (Hz)'); ylabel('\Delta (dB)')
title('Circle minus IEC screen at 0°: the driver drops out, only the baffles are left')
legend('measured', 'diffrac (piston)', 'Location', 'south')
exportgraphics(fig, fullfile(figdir, 'labE_circle_diffrac.png'), 'Resolution', 200);

%% Figure 3: IEC screen, measured 0 deg against diffrac; off/on against the piston
fig = figure('Position', [100 100 1000 760], 'Color', 'w'); try, theme(fig, 'light'); end
subplot(2,1,1)
m = dBv(ie(1).H); dex = Dii(Di_ex, 1); off = mean(dex(band)) - mean(m(band));
semilogx(f(k), m(k) + off, 'k'); hold on
semilogx(fDi, Di_pt(:, 1), 'Color', [0.85 0.33 0.10]); semilogx(fDi, Di_ex(:, 1), 'Color', [0.00 0.45 0.74]);
grid on; xlim([50 fmax]); ylim([-20 15]); ylabel('dB re free field')
title(sprintf('IEC screen %.2f x %.2f m, driver %.3f m from the left, %.2f m from the bottom, 0°', d.iec_size, d.iec_driver))
legend(sprintf('measured (shifted %+.1f dB)', off), 'diffrac, point source', 'diffrac, piston', 'Location', 'south')
subplot(2,1,2)
col = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];
ang = [15 30 60]; as = d.diam_3in/2;
for j = 1:3
    semilogx(f(k), dBv(ie(j+1).H(k)) - dBv(ie(1).H(k)), 'Color', col(j,:)); hold on
end
for j = 1:3
    x = 2*pi*f/c*as*sind(ang(j)); D = 2*besselj(1, x)./x;
    semilogx(f(k), max(dBv(D(k)), -40), '--', 'Color', col(j,:), 'LineWidth', 1);
end
grid on; xlim([200 fmax]); ylim([-35 6])
xlabel('Frequency (Hz)'); ylabel('off-axis / on-axis (dB)')
title(sprintf('IEC screen: off-axis over on-axis against a piston, a = %.0f mm (dashed)', 1e3*as))
legend('15°', '30°', '60°', 'Location', 'southwest')
exportgraphics(fig, fullfile(figdir, 'labE_iec_directivity.png'), 'Resolution', 200);

%% Part 2: System D
s0 = ld('system_0'); s30 = ld('system_30');
f2 = s0.fn; k2 = f2 <= fmax;
names = {'woofer (Scan-Speak 26W/8534G00)', 'midrange (DALI Spektor 2, 5¼")', 'tweeter (DALI Spektor 2, 25 mm dome)'};
col = [0.80 0.40 0.10; 0.20 0.40 0.70; 0.10 0.60 0.55];

% compensation distance: the one d that makes the phase smoothest (same d for all units)
ds = -10:0.001:10; cost = zeros(size(ds)); sel = f2 > 200 & f2 < 15000;
for j = 1:numel(ds)
    for u = 1:3
        ph = angle(s0.H(sel, u)) + 2*pi*f2(sel)*ds(j)/c;
        cost(j) = cost(j) + sum(abs(angle(exp(1i*diff(ph)))));
    end
end
[~, jb] = min(cost); d_comp = ds(jb);
fprintf('Compensation distance (system_0, all units): d = %.3f m\n', d_comp)

% phaseunwrap draws into the current figure, so run it in a hidden one first
PH = zeros(numel(f2), 3); ftmp = figure('Visible', 'off');
for u = 1:3
    ph = phaseunwrap(angle(s0.H(:, u))*180/pi, d_comp, f2);
    PH(:, u) = ph(:) - 360*round(interp1(f2, ph(:), 1000)/360);   % whole turns only
end
close(ftmp)

fig = figure('Position', [100 100 1000 900], 'Color', 'w'); try, theme(fig, 'light'); end
subplot(3,1,1:2)
for u = 1:3, semilogx(f2(k2), dBv(s0.H(k2, u)), 'Color', col(u,:)); hold on, end
for u = 1:3, semilogx(f2(k2), dBv(s30.H(k2, u)), ':', 'Color', col(u,:)); end
grid on; xlim([50 fmax]); ylim([-50 20]); ylabel('|H| (dB re 1 Pa/V)')
title(sprintf('System D, vent plugged, mic %.2f m at %.2f m height: 0° (solid) and 30° (dotted)', d.r_mic_2, d.h_mic_2))
legend([names, {'30°', '', ''}], 'Location', 'south')
subplot(3,1,3)
for u = 1:3, semilogx(f2(k2), PH(k2, u), 'Color', col(u,:)); hold on, end
grid on; xlim([50 fmax]); xlabel('Frequency (Hz)'); ylabel('phase (°)')
title(sprintf('0°: phase after phaseunwrap with one d = %.2f m for all three units', d_comp))
exportgraphics(fig, fullfile(figdir, 'labE_system.png'), 'Resolution', 200);

save(fullfile(resdir, 'labE_numbers.mat'), 'Delta', 'f_pk', 'f_dp', 'd_comp', 'c')
fprintf('Figures in %s\n', figdir)
