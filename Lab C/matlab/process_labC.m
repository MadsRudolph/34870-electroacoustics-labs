% PROCESS_LABC  Lab C post-processing.
%   1) Part 2: statistics of the single-frequency sensitivities (repeatability / reproducibility)
%   2) Part 3: H_pv = H_21 / H_21_ref for each microphone, noise floor check
%   3) scale to absolute sensitivity with the Part 2 value, f_s from the phase, Q from the amplitude
%   4) backplate M_AS and R_AS for the LTspice model, and the model on top of the measurement
% Expects ../data/labC_ref.mat, labC_resp_4133.mat, labC_resp_4134.mat, optional labC_noise_*.mat
% and labC_calibration_log.csv (all written by measure_labC / calibrate_labC). Figures -> ../figures/.
here = fileparts(mfilename('fullpath')); D = fullfile(here, '..', 'data'); F = fullfile(here, '..', 'figures');
if ~exist(F, 'dir'), mkdir(F); end
mics = {'4133', '4134'}; col = [0.12 0.31 0.61; 0.75 0.22 0.17];
f_mid = [60 300];                       % reference band: well above the low cut-off, far below f_s (phase still flat; a low-Q
                                        % capsule has already lost several degrees at 1 kHz, which would bias f_s upwards)

% ---- 1) sensitivities
M_use = [NaN NaN];
logf = fullfile(D, 'labC_calibration_log.csv');
if exist(logf, 'file')
    T = readtable(logf, 'TextType', 'string'); T.mic = string(T.mic);
    fprintf('\nPart 2 - sensitivities [mV/Pa]\n');
    for m = 1:2
        r = T(T.mic == mics{m}, :);
        for dev = unique(r.device)'
            v = r.M_V_per_Pa(r.device == dev) * 1e3;
            fprintf('  %s  %-14s n=%d  mean %.3f  std %.3f  (%.2f %%)\n', mics{m}, dev, numel(v), mean(v), std(v), 100*std(v)/mean(v));
        end
        v = r.M_V_per_Pa * 1e3; M_use(m) = mean(v) / 1e3;
        fprintf('  %s  ALL            n=%d  mean %.3f  std %.3f  -> %.2f dB re 1 V/Pa\n', mics{m}, numel(v), mean(v), std(v), 20*log10(M_use(m)));
    end
end

% ---- 2) responses
ref = load(fullfile(D, 'labC_ref.mat')); fn = ref.fn(:);
res = struct();
for m = 1:2
    r = load(fullfile(D, ['labC_resp_' mics{m} '.mat']));
    H = r.H21 ./ ref.H21;                                     % H_pv: system response removed
    mid = fn >= f_mid(1) & fn <= f_mid(2);
    lvl = mean(abs(H(mid))); ph = unwrap(angle(H)) * 180/pi; ph = ph - mean(ph(mid));   % phase re mid band
    Hn = abs(H) / lvl;                                        % shape, 0 dB in the mid band
    % f_s: phase has dropped 90 deg from the mid-band value (linear interpolation on log f)
    k = find(ph(1:end-1) > -90 & ph(2:end) <= -90 & fn(1:end-1) > 2000, 1);
    fs = exp(interp1(ph(k:k+1), log(fn(k:k+1)), -90));
    Q = exp(interp1(log(fn), log(Hn), log(fs)));              % Q = |H(fs)| / |H(f << fs)|, linear
    % refinement: least-squares fit of G/(1-x^2+jx/Q) to the raw complex H_pv between 100 Hz and 40 kHz. G is a real
    % gain (its sign takes care of the 180 deg ground convention) solved in closed form, so no phase reference is needed:
    % referencing to a band mean costs a degree or two on a low-Q capsule, which is 2 % in f_s.
    band = fn >= 100 & fn <= 40000; Hb = H(band); fb_ = fn(band);
    mdl  = @(p) 1 ./ (1 - (fb_/p(1)).^2 + 1j*(fb_/p(1))/p(2));
    gain = @(p) real(sum(conj(mdl(p)) .* Hb)) / sum(abs(mdl(p)).^2);
    cost = @(p) sum(abs(Hb - gain(p)*mdl(p)).^2 ./ abs(gain(p)*mdl(p)).^2);
    pfit = fminsearch(cost, [fs Q], optimset('TolX', 1e-8, 'TolFun', 1e-12, 'MaxFunEvals', 4000, 'MaxIter', 4000));
    lvl = abs(gain(pfit)); Hn = abs(H) / lvl; ph = unwrap(angle(H / sign(gain(pfit)))) * 180/pi; ph = ph - 360*round(mean(ph(mid))/360);
    fprintf('%s: slide procedure fs = %.0f Hz, Q = %.3f   |   least-squares fit fs = %.0f Hz, Q = %.3f\n', mics{m}, fs, Q, pfit(1), pfit(2));
    res.(['m' mics{m}]) = struct('H', H, 'Hn', Hn, 'ph', ph, 'fs_slide', fs, 'Q_slide', Q, 'fs', pfit(1), 'Q', pfit(2));
end

% ---- 4) model parameters from the brief + (fs, Q)
rho = 1.18; c = 344; a = 8.95e-3/2; x0 = 20.77e-6; E = 200; MMD = 1.5e-6; CMD = 0.02e-3; Vb = 126.4e-9;
SD = pi*a^2; CAB = Vb/(rho*c^2); MA1 = 0.6133*rho/(pi*a); CMT = 1/(1/CMD + SD^2/CAB); Mmodel = E*SD*CMT/x0;
fprintf('\nModel constants: S_D = %.4g m^2, C_MT = %.4g m/N, model sensitivity %.2f mV/Pa\n', SD, CMT, Mmodel*1e3);
fprintf('\n%-6s %10s %8s %8s %14s %16s\n', 'mic', 'fs [Hz]', 'Q', '20logQ', 'M_AS [kg/m4]', 'R_AS [Pa s/m3]');
for m = 1:2
    s = res.(['m' mics{m}]); MMT = 1/((2*pi*s.fs)^2*CMT);
    MAS = (MMT - MMD)/SD^2 - MA1; RAS = sqrt(MMT/CMT)/s.Q/SD^2;
    fprintf('%-6s %10.0f %8.3f %8.2f %14.1f %16.4g   ->  .param fs%s=%.0f Q%s=%.3f\n', mics{m}, s.fs, s.Q, 20*log10(s.Q), MAS, RAS, mics{m}(3:4), s.fs, mics{m}(3:4), s.Q);
    x = fn / s.fs; res.(['m' mics{m}]).model = 1 ./ (1 - x.^2 + 1j*x/s.Q);
end

% ---- figures
fg = figure(1); clf(fg); try, theme(fg, 'light'); catch, set(fg, 'Color', 'w'); end
ax1 = subplot(2, 1, 1); hold on; ax2 = subplot(2, 1, 2); hold on
for m = 1:2
    s = res.(['m' mics{m}]); k = 20*log10(M_use(m)); if isnan(k), k = 0; end
    semilogx(ax1, fn, 20*log10(s.Hn) + k, '-', 'Color', col(m, :), 'LineWidth', 1.6, 'DisplayName', ['B&K ' mics{m} ' measured']);
    semilogx(ax1, fn, 20*log10(abs(s.model)) + k, '--', 'Color', col(m, :), 'LineWidth', 1.2, 'DisplayName', sprintf('model: f_s = %.1f kHz, Q = %.2f', s.fs/1e3, s.Q));
    plot(ax1, s.fs, 20*log10(s.Q) + k, 'o', 'Color', col(m, :), 'HandleVisibility', 'off');
    semilogx(ax2, fn, s.ph, '-', 'Color', col(m, :), 'LineWidth', 1.6); semilogx(ax2, fn, unwrap(angle(s.model))*180/pi, '--', 'Color', col(m, :), 'LineWidth', 1.2);
end
set([ax1 ax2], 'XScale', 'log', 'XLim', [20 60000]); grid(ax1, 'on'); grid(ax2, 'on'); legend(ax1, 'Location', 'southwest')
if all(~isnan(M_use)), ylabel(ax1, 'sensitivity [dB re 1 V/Pa]'); else, ylabel(ax1, 'response re mid band [dB]'); end
ylabel(ax2, 'phase re mid band [deg]'); xlabel(ax2, 'Frequency [Hz]'); yline(ax2, -90, ':', 'HandleVisibility', 'off'); ylim(ax2, [-200 20])
title(ax1, 'Lab C: actuator response, measurement vs. second-order model')
exportgraphics(fg, fullfile(F, 'labC_responses_vs_model.png'), 'Resolution', 200);

nf = dir(fullfile(D, 'labC_noise_*.mat'));
if ~isempty(nf)
    fg = figure(2); clf(fg); try, theme(fg, 'light'); catch, set(fg, 'Color', 'w'); end; hold on
    r = load(fullfile(D, 'labC_resp_4133.mat')); semilogx(fn, 20*log10(abs(r.specn(:, 2))), 'k-', 'LineWidth', 1.6, 'DisplayName', 'signal, 4133, actuator ON');
    for k = 1:numel(nf), n = load(fullfile(D, nf(k).name)); semilogx(n.fn, 20*log10(abs(n.specn(:, 2))), 'DisplayName', strrep(nf(k).name(6:end-4), '_', ' ')); end
    set(gca, 'XScale', 'log'); grid on; xlim([20 60000]); xlabel('Frequency [Hz]'); ylabel('microphone channel [dB re 1 V]'); legend('Location', 'best')
    title('Noise floor vs. signal (averaging 16x more lowers uncorrelated noise by 12 dB)')
    exportgraphics(fg, fullfile(F, 'labC_noise_floor.png'), 'Resolution', 200);
end
