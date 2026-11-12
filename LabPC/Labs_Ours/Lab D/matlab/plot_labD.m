%% Lab D: every figure for the report
% Reads the cleaned files in ../data (made by import_labD) and the hand
% measurements in labD_dims, and saves each figure as a PNG in ../figures.
% Run it from anywhere; it changes to this folder first.

here = fileparts(mfilename('fullpath'));
cd(here)
datadir = fullfile(here, '..', 'data');
figdir  = fullfile(here, '..', 'figures');
if ~exist(figdir, 'dir'), mkdir(figdir); end
ld = @(tag) load(fullfile(datadir, ['labD_' tag '.mat']));
d = labD_dims();

%% 1. Tweeter impedance (2a1)
tw = ld('tweeter');
figure('Name', 'Tweeter', 'Position', [100 100 700 550]);
subplot(2,1,1)
semilogx(tw.fn, abs(tw.Z), 'LineWidth', 1.2); hold on
yline(d.RE_tweeter, '--k', sprintf('R_E = %.1f \\Omega', d.RE_tweeter));
grid on; xlim([100 24000]); ylabel('|Z| (\Omega)')
title('Tweeter input impedance')
subplot(2,1,2)
semilogx(tw.fn, angle(tw.Z)*180/pi, 'LineWidth', 1.2)
grid on; xlim([100 24000]); ylabel('phase (deg)'); xlabel('frequency (Hz)')
exportgraphics(gcf, fullfile(figdir, 'labD_tweeter.png'), 'Resolution', 200);

%% 2. Midrange impedance (2a2)
mr = ld('midrange');
figure('Name', 'Midrange', 'Position', [100 100 700 550]);
subplot(2,1,1)
semilogx(mr.fn, abs(mr.Z), 'LineWidth', 1.2); hold on
yline(d.RE_midrange, '--k', sprintf('R_E = %.1f \\Omega', d.RE_midrange));
grid on; xlim([20 20000]); ylabel('|Z| (\Omega)')
title('Midrange input impedance')
subplot(2,1,2)
semilogx(mr.fn, angle(mr.Z)*180/pi, 'LineWidth', 1.2)
grid on; xlim([20 20000]); ylabel('phase (deg)'); xlabel('frequency (Hz)')
exportgraphics(gcf, fullfile(figdir, 'labD_midrange.png'), 'Resolution', 200);

%% 3. Woofer: free air and closed box (2b1, 2b2)
fr = ld('woofer_free');
cl = ld('woofer_closed');
tsf = ts_from_Z(fr.fn, fr.Z, d.RE_woofer);
tsc = ts_from_Z(cl.fn, cl.Z, d.RE_woofer);
figure('Name', 'Woofer free/closed', 'Position', [100 100 700 550]);
subplot(2,1,1)
semilogx(fr.fn, abs(fr.Z), 'LineWidth', 1.2); hold on
semilogx(cl.fn, abs(cl.Z), 'LineWidth', 1.2)
xline(tsf.f0, ':', sprintf('f_s = %.1f Hz', tsf.f0));
xline(tsc.f0, ':', sprintf('f_c = %.1f Hz', tsc.f0));
yline(d.RE_woofer, '--k', sprintf('R_E = %.1f \\Omega', d.RE_woofer));
grid on; xlim([5 10000]); ylabel('|Z| (\Omega)')
legend('free air', 'closed box', 'Location', 'northeast')
title('Woofer input impedance')
subplot(2,1,2)
semilogx(fr.fn, angle(fr.Z)*180/pi, 'LineWidth', 1.2); hold on
semilogx(cl.fn, angle(cl.Z)*180/pi, 'LineWidth', 1.2)
grid on; xlim([5 10000]); ylabel('phase (deg)'); xlabel('frequency (Hz)')
exportgraphics(gcf, fullfile(figdir, 'labD_woofer_free_closed.png'), 'Resolution', 200);

%% 4. Woofer with the vent open, three tube lengths (2b4)
figure('Name', 'Woofer vents', 'Position', [100 100 700 550]);
subplot(2,1,1)
semilogx(cl.fn, abs(cl.Z), 'k', 'LineWidth', 1); hold on
names = {'closed box'};
for k = 1:size(d.vents, 1)
    [tag, L, N] = d.vents{k, :};
    v = ld(tag);
    semilogx(v.fn, abs(v.Z), 'LineWidth', 1.2)
    names{end+1} = sprintf('vent L = %.0f mm, %d open', 1e3*L, N); %#ok<SAGROW>
end
grid on; xlim([5 300]); ylabel('|Z| (\Omega)')
legend(names, 'Location', 'northeast')
title('Woofer input impedance, vented box')
subplot(2,1,2)
semilogx(cl.fn, angle(cl.Z)*180/pi, 'k', 'LineWidth', 1); hold on
for k = 1:size(d.vents, 1)
    v = ld(d.vents{k, 1});
    semilogx(v.fn, angle(v.Z)*180/pi, 'LineWidth', 1.2)
end
grid on; xlim([5 300]); ylabel('phase (deg)'); xlabel('frequency (Hz)')
exportgraphics(gcf, fullfile(figdir, 'labD_woofer_vents.png'), 'Resolution', 200);

%% 5. Near field: cone and vent at each tube length (part 3)
% The dotted line is f_b read off the impedance minimum at the same length.
nL = size(d.nearfield, 1);
figure('Name', 'Near field', 'Position', [100 100 700 250*nL]);
for k = 1:nL
    [ct, vt, L] = d.nearfield{k, :};
    cn = ld(ct); vn = ld(vt);
    iv = find([d.vents{:, 2}] == L, 1);
    subplot(nL, 1, k)
    semilogx(cn.fn, 20*log10(abs(cn.H)), 'LineWidth', 1.2); hold on
    semilogx(vn.fn, 20*log10(abs(vn.H)), 'LineWidth', 1.2)
    if ~isempty(iv)
        vz = ld(d.vents{iv, 1});
        v = fb_from_Z(vz.fn, vz.Z);
        xline(v.fb, ':', sprintf('f_b(Z) = %.1f Hz', v.fb));
    end
    grid on; xlim([5 1000]); ylabel('|p/V| (dB re 1 Pa/V)')
    title(sprintf('Near field, vent L = %.0f mm', 1e3*L))
    legend('cone', 'vent', 'Location', 'southwest')
end
xlabel('frequency (Hz)')
exportgraphics(gcf, fullfile(figdir, 'labD_nearfield.png'), 'Resolution', 200);

%% 6. Repeat runs: how much the result moves between runs
% Bold = the run used above. Same resistor (32.9 ohm) in every run.
figure('Name', 'Repeats', 'Position', [100 100 700 750]);
sets = {'tweeter', [100 24000]; 'midrange', [20 20000]; 'woofer_free', [5 10000]};
for s = 1:size(sets, 1)
    subplot(size(sets, 1), 1, s)
    files = dir(fullfile(datadir, ['labD_' sets{s, 1} '_r*.mat']));
    used = ld(sets{s, 1});
    names = {};
    for k = 1:numel(files)
        r = load(fullfile(datadir, files(k).name));
        lw = 0.8 + 1.2*strcmp(r.src, used.src);
        semilogx(r.fn, abs(r.Z), 'LineWidth', lw); hold on
        names{end+1} = strrep(files(k).name(6:end-4), '_', '\_'); %#ok<SAGROW>
    end
    grid on; xlim(sets{s, 2}); ylabel('|Z| (\Omega)')
    title(['Repeats: ' strrep(sets{s, 1}, '_', ' ')])
    legend(names, 'Location', 'eastoutside')
end
xlabel('frequency (Hz)')
exportgraphics(gcf, fullfile(figdir, 'labD_repeats.png'), 'Resolution', 200);

fprintf('Figures saved in %s\n', figdir);
