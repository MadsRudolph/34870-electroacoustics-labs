% PROCESS_LABB  Lab B post-processing: normalise the mock-up measurements with the no-mock-up
% reference, compare with the BEM model, scale to real microphone sizes.
%
% Expects  ../data/labB_nomockup.mat, labB_ang000.mat, labB_ang045.mat, labB_ang090.mat, ...
% (written by measure_labB) and ../bem/bem_results.mat (written by bem/run_bem.m).
% Figures go to ../figures/.  Set D_mockup to the diameter you measured with the tape.
D_mockup = 0.250;                         % [m]  <-- measured diameter of the mock-up
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here, '..', 'data'); figDir = fullfile(here, '..', 'figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end
ref = load(fullfile(dataDir, 'labB_nomockup.mat'));
files = dir(fullfile(dataDir, 'labB_ang*.mat')); files = files(cellfun(@isempty, regexp({files.name}, '_\d+\.mat$')));   % skip repeats
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

function lightfig(n)
% report figures on a white background even when MATLAB follows a dark desktop theme
fg = figure(n); clf(fg); try, theme(fg, 'light'); catch, set(fg, 'Color', 'w'); end
end
