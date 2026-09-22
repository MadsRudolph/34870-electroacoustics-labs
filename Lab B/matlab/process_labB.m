% PROCESS_LABB  Lab B post-processing: normalise the mock-up measurements with the no-mock-up
% reference, compare with the BEM model, scale to real microphone sizes.
%
% Expects  ../data/labB_nomockup.mat, labB_ang000.mat, labB_ang045.mat, labB_ang090.mat, ...
% (written by measure_labB, or by import_group_files from the files the course script saved on 22-Sep) and ../bem/bem_results.mat (written by bem/run_bem.m).
% Figures go to ../figures/.  Set D_mockup to the diameter you measured with the tape.
D_mockup = 0.250;                         % [m]  nominal (brief/BEM) diameter: the tape measurement was not taken on 22-Sep-2026
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here, '..', 'data'); figDir = fullfile(here, '..', 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end
ref = load(latest(dataDir, 'nomockup'));
tags = unique(regexprep({dir(fullfile(dataDir, 'labB_ang*.mat')).name}, '^labB_(ang\d+).*$', '$1'));
files = cellfun(@(t) dir(latest(dataDir, t)), tags);     % one file per angle: the LAST repeat (measure_labB never overwrites)
bem = load(fullfile(here, '..', 'bem', 'bem_results.mat'));
col = lines(numel(files));

% ---- 1) normalised responses = pressure increase caused by the body (free-field correction of the mock-up)
lightfig(1); hold on
for k = 1:numel(files)
    m = load(fullfile(dataDir, files(k).name)); ang(k) = sscanf(files(k).name, 'labB_ang%d'); %#ok<SAGROW>
    Hn(:, k) = m.H ./ ref.H; %#ok<SAGROW>
    semilogx(m.fn, 20*log10(abs(Hn(:, k))), '-', 'Color', col(k, :), 'LineWidth', 1.4, 'DisplayName', sprintf('measured, %d°', ang(k)));
    [~, ia] = min(abs(bem.angles - ang(k)));
    semilogx(bem.fr, 20*log10(abs(bem.Round.p_centre(ia, :))), '--', 'Color', col(k, :), 'LineWidth', 1.2, 'DisplayName', sprintf('BEM round end, %d°', bem.angles(ia)));
end
fn = ref.fn; set(gca, 'XScale', 'log'); grid on; xlim([50 10000]); ylim([-15 15])
xlabel('Frequency [Hz]'); ylabel('|H_{ang} / H_{no mock-up}|  [dB]'); legend('Location', 'southwest')
title('Lab B: pressure at the face centre of the mock-up relative to the free field')
exportgraphics(gcf, fullfile(figDir, 'labB_measured_vs_bem.png'), 'Resolution', 200);

% ---- 2) what the BEM says about WHERE you measure: centre, 3 cm in front, diaphragm average (0 deg)
lightfig(2)
semilogx(bem.fr, 20*log10(abs(bem.Round.p_centre(1, :))), 'b-', bem.fr, 20*log10(abs(bem.Round.p_FP(1, :))), 'r-', ...
         bem.fr, 20*log10(abs(bem.Round.p_avg(1, :))), 'g-', bem.fr, 20*log10(abs(bem.Flat.p_centre(1, :))), 'k:', 'LineWidth', 1.4); grid on
legend('face centre', 'field point 3 cm in front', 'parabolic average over the face', 'face centre, FLAT back end', 'Location', 'northwest')
xlabel('Frequency [Hz]'); ylabel('dB re incident pressure'); title('BEM, 0° incidence'); xlim([50 5400])
exportgraphics(gcf, fullfile(figDir, 'labB_bem_positions.png'), 'Resolution', 200);

% ---- 3) scaling: the same curves on the frequency axis of real microphones (f_mic = f_mockup * D_mockup / D_mic)
mics = struct('name', {'1"', '1/2"', '1/4"', '1/8"'}, 'D', {23.77e-3, 12.7e-3, 6.35e-3, 3.175e-3});
lightfig(3)
for q = 1:numel(mics)
    s = D_mockup / mics(q).D;
    subplot(2, 2, q); hold on
    for k = 1:numel(files)
        semilogx(fn * s / 1e3, 20*log10(abs(Hn(:, k))), '-', 'Color', col(k, :), 'LineWidth', 1.2, 'DisplayName', sprintf('%d°', ang(k)));
    end
    set(gca, 'XScale', 'log'); grid on; ylim([-10 14]); xlim([1 100]); xlabel('Frequency [kHz]'); ylabel('dB')
    title(sprintf('%s microphone, scale factor %.1f', mics(q).name, s)); if q == 1, legend('Location', 'northwest'); end
end
exportgraphics(gcf, fullfile(figDir, 'labB_scaled_to_microphones.png'), 'Resolution', 200);

% ---- 2b) where did the UMIK tip sit?  measured 0 deg against the BEM at the face centre and at the 3 cm field point
lightfig(6); hold on
k0 = find(ang == 0, 1);
if ~isempty(k0)
    semilogx(fn, 20*log10(abs(Hn(:, k0))), 'b-', 'LineWidth', 1.6, 'DisplayName', 'measured, 0°');
    semilogx(bem.fr, 20*log10(abs(bem.Round.p_centre(1, :))), 'k--', 'LineWidth', 1.2, 'DisplayName', 'BEM, face centre');
    semilogx(bem.fr, 20*log10(abs(bem.Round.p_FP(1, :))), 'r-.', 'LineWidth', 1.4, 'DisplayName', 'BEM, field point 3 cm in front of the face');
    semilogx(bem.fr, 20*log10(abs(bem.Round.p_avg(1, :))), 'g:', 'LineWidth', 1.4, 'DisplayName', 'BEM, parabolic average over the face');
    set(gca, 'XScale', 'log'); grid on; xlim([100 10000]); ylim([-25 15]); legend('Location', 'southwest')
    xlabel('Frequency [Hz]'); ylabel('dB re no mock-up'); title('0° incidence: the notch tells where the UMIK tip was')
    exportgraphics(gcf, fullfile(figDir, 'labB_tip_position.png'), 'Resolution', 200);
    m = fn > 3000 & fn < 4500; [nv, ni] = min(20*log10(abs(Hn(m, k0)))); fm = fn(m);
    fprintf('0 deg notch: %.1f dB at %.0f Hz  (quarter-wave gap c/4f = %.1f cm)\n', nv, fm(ni), 344 / 4 / fm(ni) * 100);
end

% ---- numbers for the report: low-frequency level, peak below 2 kHz, level at the BEM peak (1345 Hz)
fprintf('%-6s %-16s %-22s %-12s\n', 'angle', '125-200 Hz mean', 'peak below 2 kHz', 'at 1345 Hz');
for k = 1:numel(files)
    d = 20*log10(abs(Hn(:, k))); m = fn > 200 & fn < 2000; [pv, pi] = max(d(m)); fm = fn(m);
    fprintf('%-6d %-16.2f %5.1f dB at %5.0f Hz      %5.1f\n', ang(k), mean(d(fn >= 125 & fn <= 200)), pv, fm(pi), d(nearest(fn, 1345)));
end

% ---- 3b) did anything drift? reference taken again at the end of the series (tag 'nomockup_end')
fe = dir(fullfile(dataDir, 'labB_nomockup_end*.mat'));
if ~isempty(fe)
    e = load(latest(dataDir, 'nomockup_end'));
    lightfig(5); semilogx(fn, 20*log10(abs(e.H ./ ref.H)), 'k-', 'LineWidth', 1.2); grid on; xlim([50 10000]); ylim([-3 3])
    xlabel('Frequency [Hz]'); ylabel('dB'); title('no-mock-up reference at the end / at the start  (should be 0 dB: nothing moved)')
    exportgraphics(gcf, fullfile(figDir, 'labB_reference_drift.png'), 'Resolution', 200);
    fprintf('reference drift, end vs start: max %.2f dB (125 Hz - 10 kHz)\n', max(abs(20*log10(abs(e.H(fn >= 125) ./ ref.H(fn >= 125))))));
end

% ---- 4) Part 0 (optional): 1/r check from labB_dist<cm>cm.mat files
dfiles = dir(fullfile(dataDir, 'labB_dist*cm.mat'));
if numel(dfiles) >= 2
    lightfig(4); hold on
    for k = 1:numel(dfiles)
        m = load(fullfile(dataDir, dfiles(k).name)); r(k) = sscanf(dfiles(k).name, 'labB_dist%d') / 100; %#ok<SAGROW>
        Hd(:, k) = m.H; %#ok<SAGROW>
    end
    [r, o] = sort(r); Hd = Hd(:, o);
    for k = 2:numel(r)
        semilogx(fn, 20*log10(abs(Hd(:, k) ./ Hd(:, 1))), 'LineWidth', 1.2, 'DisplayName', sprintf('%.2f m vs %.2f m: measured', r(k), r(1)));
        yline(20*log10(r(1) / r(k)), '--', sprintf('1/r law: %.1f dB', 20*log10(r(1) / r(k))), 'HandleVisibility', 'off');
    end
    set(gca, 'XScale', 'log'); grid on; xlim([50 10000]); xlabel('Frequency [Hz]'); ylabel('level difference [dB]'); legend
    title('Part 0: free-field check (chamber cut-off 125 Hz)')
    exportgraphics(gcf, fullfile(figDir, 'labB_free_field_check.png'), 'Resolution', 200);
end

function p = latest(dataDir, tag)
% newest repeat of a tag: labB_<tag>.mat, labB_<tag>_2.mat, ... -> the highest number wins
c = dir(fullfile(dataDir, ['labB_' tag '*.mat'])); c = c(~cellfun(@isempty, regexp({c.name}, ['^labB_' tag '(_\d+)?\.mat$'])));
if isempty(c), error('no file labB_%s*.mat in %s', tag, dataDir); end
n = cellfun(@(x) max([1 sscanf(regexprep(x, ['^labB_' tag '_?'], ''), '%d')]), {c.name});
[~, i] = max(n); p = fullfile(dataDir, c(i).name); fprintf('%-14s <- %s\n', tag, c(i).name);
end

function lightfig(n)
% report figures on a white background even when MATLAB follows a dark desktop theme
fg = figure(n); clf(fg); try, theme(fg, 'light'); catch, set(fg, 'Color', 'w'); end
end

function i = nearest(fn, f0)
[~, i] = min(abs(fn - f0));
end
