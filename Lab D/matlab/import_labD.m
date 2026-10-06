function import_labD()
% IMPORT_LABD  Turn the lab-PC files in "raw data/" into clean, small data/ files.
%
%   What went wrong on the day (6-Oct-2026), and what this undoes:
%   - Tags were reused: vent_L1, vent_L1_2, ... for every tube length. The
%     length is in each file's note, so the table below gives every run a
%     tag that says what it is.
%   - 'R' was given the driver's R_E (3.4 / 4.6 / 5.7) instead of the
%     series resistor, so the saved Z is wrong. Z is recomputed here from
%     specn with the resistor actually used, R = 32.9 ohm.
%   - AI0 (V_amp) reads half the amplifier voltage on top of a ~9.4 V DC
%     offset (one leg of a bridged output, presumably). With V_amp = 2*AI0
%     |Z| settles on R_E at low frequency for all three drivers and the free-air peak matches the data sheet (117 ohm), so k = 2 is
%     applied to both Z and the near-field H.
%
%   Each output file keeps fn, specn, the metadata and the corrected Z or H,
%   but not the 768000-point f/spec/ch (those stay in raw data/). The plain
%   tag (labD_woofer_free.mat ...) is the run used in the analysis; every run
%   is also saved as <tag>_rN in the order it was taken.

here = fileparts(mfilename('fullpath'));
rawdir = fullfile(here, '..', 'raw data', 'LabD_measurements', 'data');
datadir = fullfile(here, '..', 'data');
if ~exist(datadir, 'dir'), mkdir(datadir); end

R = 32.9;   % series resistor used for every impedance run (multimeter)
k = 2;      % true V_amp = k * AI0

% raw file,             clean tag,          repeat, used?, vent length (m)
runs = {
    'labD_tweeter',          'tweeter',          1, false, NaN
    'labD_tweeter_2',        'tweeter',          2, false, NaN
    'labD_tweeter_3',        'tweeter',          3, false, NaN
    'labD_tweeter_4',        'tweeter',          4, false, NaN
    'labD_tweeter_5',        'tweeter',          5, true,  NaN
    'labD_tweeter2',         'tweeter',          6, false, NaN
    'labD_tweeter_6',        'tweeter',          7, false, NaN
    'labD_tweeter_7',        'tweeter',          8, false, NaN
    'labD_midrange',         'midrange',         1, false, NaN
    'labD_midrange_2',       'midrange',         2, false, NaN
    'labD_midrange_3',       'midrange',         3, true,  NaN
    'labD_midrange_4',       'midrange',         4, false, NaN
    'labD_woofer_free',      'woofer_free',      1, false, NaN
    'labD_woofer_free_2',    'woofer_free',      2, true,  NaN
    'labD_woofer_free_3',    'woofer_free',      3, false, NaN
    'labD_woofer_free_4',    'woofer_free',      4, false, NaN
    'labD_woofer_free_5',    'woofer_free',      5, false, NaN
    'labD_woofer_closed',    'woofer_closed',    1, true,  NaN
    'labD_vent_L1',          'vent_L200',        1, true,  0.200
    'labD_vent_L1_2',        'vent_L160',        1, true,  0.160
    'labD_vent_L1_3',        'vent_L240',        1, true,  0.240
    'labD_nf_cone_L1',       'nf_cone_L240',     1, false, 0.240
    'labD_nf_cone_L1_2',     'nf_cone_L240',     2, true,  0.240
    'labD_nf_vent_L1',       'nf_vent_L240',     1, true,  0.240
    'labD_nf_vent_L1_2',     'nf_vent_L200',     1, true,  0.200
    'labD_nf_cone_L1_3',     'nf_cone_L200',     1, true,  0.200
    'labD_nf_cone_L1_4',     'nf_cone_L160',     1, true,  0.160
    'labD_nf_vent_L1_3',     'nf_vent_L160',     1, true,  0.160
};

for i = 1:size(runs, 1)
    [src, tag, rep, used, L] = runs{i, :};
    raw = load(fullfile(rawdir, [src '.mat']));

    m = struct('tag', tag, 'src', [src '.mat'], 'kind', raw.kind, ...
        'note', raw.note, 'L_vent', L, 'time', raw.time, ...
        'f1', raw.f1, 'f2', raw.f2, 'n_oct', raw.n_oct, 'fres', raw.fres, ...
        'Nav', raw.Nav, 'R', R, 'R_typed', raw.R, 'k_amp', k, ...
        'NexusVperPa', raw.NexusVperPa, 'fn', raw.fn, 'specn', raw.specn, ...
        'rms', raw.rms, 'peak', raw.peak, ...
        'dc_AI0', mean(raw.ch(:,1)), ...
        'clip_AI0', mean(raw.ch(:,1) >= 10.5));   % fraction of samples on the rail

    if strcmp(raw.kind, 'nearfield')
        m.H = (raw.specn(:,2) / raw.NexusVperPa) ./ (k * raw.specn(:,1));
    else
        G = raw.specn(:,2) ./ (k * raw.specn(:,1));
        m.Z = R * G ./ (1 - G);
    end

    save(fullfile(datadir, sprintf('labD_%s_r%d.mat', tag, rep)), '-struct', 'm');
    if used
        save(fullfile(datadir, ['labD_' tag '.mat']), '-struct', 'm');
    end
    fprintf('%-20s -> %-16s r%d%s\n', src, tag, rep, repmat(' (used)', 1, used));
end
end
