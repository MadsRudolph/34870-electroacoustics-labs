function pad_predict()
% PAD_PREDICT  What other L-pads would do to the MEASURED system (run R2 of 10-Nov).
%   R2 holds mid, tweeter and all in one run (one clock), so woofer = all - mid - tw,
%   and a new pad = tweeter x (T_new / T_old) from the board model (../model/pad_ratio.csv).
here = fileparts(mfilename('fullpath')); addpath(fullfile(here, '..', 'kit', 'core')); LP = labpaths('all');
m = load(fullfile(LP.data, 'project_R2_units_0.mat'));
fn = m.fn; mid = m.H(:,1); tw = m.H(:,2); all = m.H(:,3); woof = all - mid - tw;
T = readmatrix(fullfile(LP.model, 'pad_ratio.csv'), 'NumHeaderLines', 1);
fid = fopen(fullfile(LP.model, 'pad_ratio.csv')); hdr = strsplit(fgetl(fid), ','); fclose(fid);
b = fn >= 150 & fn <= 15000;
sm = @(x) lab_smooth(fn, 20*log10(abs(x)));
fprintf('%-12s %8s %8s %8s\n', 'pad Rs/Rp', 'spread', 'rms', 'tw 5-15k');
for j = 2:2:numel(hdr)
    G = interp1(T(:,1), T(:,j) + 1j*T(:,j+1), fn, 'linear', 'extrap');
    s = sm(woof + mid + tw .* G); s = s(b);
    nm = strrep(erase(hdr{j}, {'R', '_re'}), '_', '/');
    fprintf('%-12s %6.1f dB %6.2f dB %+6.1f dB\n', nm, max(s) - min(s), std(s), median(20*log10(abs(G(fn > 5000 & fn < 15000)))));
end
end
