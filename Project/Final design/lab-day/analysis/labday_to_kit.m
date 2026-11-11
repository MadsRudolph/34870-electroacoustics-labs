function labday_to_kit()
% LABDAY_TO_KIT  10-Nov runs (../data/*.mat, made by import_labday) -> the kit's format in
%   ../data/2026-11-10/, so  lab_dash('../data/2026-11-10')  shows that day like any kit session.
%   Left out: R1 try 1 and R2 try 1 (their 'all' state was not what it says).

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..', 'kit', 'core')); L = labpaths;   % all folders + the called code
src = L.data;
out = fullfile(src, '2026-11-10');
if ~exist(out, 'dir'), mkdir(out); end
S0 = lab_setup(); S0.date = '2026-11-10'; S0.amp_volume = 'about 45 %';

%  file                    label         ids                     note
c = {
  'project_R1_try2_0',   'S_try2',     {'S1','S2','S3'},       'R1 try 2: Out 1 still 0 dB (woofer 6 dB loud)'
  'project_R1_split_0',  'S',          {'S1','S2','S3'},       'R1 try 3: Out 1 -5.8 dB'
  'project_R2_units_0',  'S4+S5+S3',   {'S4','S5','S3'},       'R2: mid / tweeter / all'
  'project_R3_flip_0',   'F',          {'F0','F1','F2'},       'R3: polarity flips'
  'project_R5_repeat_0', 'S_repeat',   {'S1','S2','S3'},       'R5: repeat of R1'
};
for i = 1:size(c, 1)
    m = load(fullfile(src, [c{i,1} '.mat']));
    S = S0; S.out1_gain = m.dims.minidsp_out1_gain;
    k = struct('label', c{i,2}, 'ids', {c{i,3}}, 'station', 'chamber', 'angle', m.angle_deg, ...
        'dsp', 'on', 'setup', S, 'note', c{i,4}, 'time', m.time, 'fn', m.fn, 'H', m.H, ...
        'peak', m.peak, 'Nav', m.Nav, 'specn', m.specn, 'src', c{i,1});
    save(fullfile(out, [c{i,2} '.mat']), '-struct', 'k');
end
S = S0; S.vent_mm = 200;
for n = {{'zinf_nf_cone_L200', 'N1'}, {'zinf_nf_vent_L200', 'N2'}}
    m = load(fullfile(src, [n{1}{1} '.mat']));
    k = struct('label', n{1}{2}, 'ids', {{n{1}{2}}}, 'station', 'zinf', 'angle', 0, 'dsp', '', ...
        'setup', S, 'note', m.note, 'time', m.time, 'fn', m.fn, 'H', m.H, 'k_amp', m.k_amp, ...
        'dc_AI0', m.dc_AI0, 'clip', m.clip, 'peak', m.peak, 'Nav', m.Nav, 'specn', m.specn, 'src', n{1}{1});
    save(fullfile(out, [n{1}{2} '.mat']), '-struct', 'k');
end
fprintf('Wrote %s\n', out);
end
