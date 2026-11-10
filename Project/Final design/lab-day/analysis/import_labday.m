function import_labday()
% IMPORT_LABDAY  Lab day 10-Nov-2026: raw lab-PC files -> small, annotated files in ../data/.
%
%   ../raw data/anechoic/project_*.mat and ../raw data/nearfield/zinf_*.mat are the
%   untouched files from the USB stick (~100 MB, in git: full spectra and time
%   signals). This keeps what the analysis needs (fn, specn, H, states, metadata),
%   drops spec/ch, and adds what was only known afterwards:
%     - the MiniDSP Out 1 gain was lowered by 5.8 dB to -10.3 dB before R1 try 3
%       (R1 try 2 showed the woofer 6.4 dB too loud against mid+tweeter);
%       tries 1 and 2 ran at -4.5 dB
%     - mutes were made by pulling the amplifier speaker cable, not in the app
%     - the near field was measured with the vent at 200 mm (not 160), and the
%       vent file was saved as 'L1200' by a typo -> renamed nf_vent_L200
%     - 'used' = the run is valid; 'problem' says why not
%   project_dims was not filled in on the day; the values the group gave afterwards
%   (amplifier ~45 %, placement as in Lab E, filters from the .txt files) are added.

here = fileparts(mfilename('fullpath')); addpath(fullfile(here, '..', 'kit', 'core')); LP = labpaths('all');
raw = fullfile(LP.root, 'raw data');
out = LP.data;
if ~exist(out, 'dir'), mkdir(out); end

%  raw file                       saved as                 used   Out1 dB  problem
runs = {
  'project_R1_split_0.mat',     'project_R1_try1_0',     false, -4.5,  'woofer silent in the ''all'' state (cable not back in time); mid+tw far too loud'
  'project_R1_split_0_2.mat',   'project_R1_try2_0',     false, -4.5,  'woofer 6.4 dB too loud against mid+tw: Out 1 lowered by 5.8 dB afterwards'
  'project_R1_split_0_3.mat',   'project_R1_split_0',    true,  -10.3, ''
  'project_R2_units_0.mat',     'project_R2_try1_0',     false, -10.3, '''all'' state not switched in time (still tweeter only)'
  'project_R2_units_0_2.mat',   'project_R2_units_0',    true,  -10.3, ''
  'project_R3_flip_0.mat',      'project_R3_flip_0',     true,  -10.3, ''
  'project_R5_repeat_0.mat',    'project_R5_repeat_0',   true,  -10.3, ''
};
for i = 1:size(runs, 1)
    [src, tag, used, g1, prob] = runs{i, :};
    m = load(fullfile(raw, 'anechoic', src));
    m = rmfield(m, intersect(fieldnames(m), {'spec', 'ch', 'f'}));
    m.src = src; m.tag = tag; m.used = used; m.problem = prob;
    m.dims.minidsp_out1_gain = g1;
    m.dims.mute_method = 'speaker cable pulled at the amplifier';
    m.dims.dust_cover = 'off';
    m.dims = filled(m.dims);
    save(fullfile(out, [tag '.mat']), '-struct', 'm');
    fprintf('%-26s -> %-22s %s\n', src, tag, ternary(used, 'used', ['NOT used: ' prob]));
end

nf = {
  'zinf_nf_cone_L200.mat',   'zinf_nf_cone_L200',  'cone, one vent at 200 mm'
  'zinf_nf_vent_L1200.mat',  'zinf_nf_vent_L200',  'vent mouth, one vent at 200 mm (saved as L1200 by a typo)'
};
for i = 1:size(nf, 1)
    [src, tag, note] = nf{i, :};
    m = load(fullfile(raw, 'nearfield', src));
    m = rmfield(m, intersect(fieldnames(m), {'spec', 'ch', 'f'}));
    m.src = src; m.tag = tag; m.note = note; m.used = true; m.L_vent = 0.200;
    m.dims = filled(m.dims);
    m.dims.vent_used = 'one vent at 200 mm (the group''s memory of Lab D; the design is 160 mm)';
    save(fullfile(out, [tag '.mat']), '-struct', 'm');
    fprintf('%-26s -> %s\n', src, tag);
end
end

function d = filled(d)
% Told by the group afterwards (10-Nov evening)
d.amp_volume  = 'about 45 %';
d.r_mic       = 2.44;            % same placement as Lab E
d.h_mic       = 1.15;
d.layout      = 'as in Lab E';
d.minidsp_cfg = 'filters pasted from data/dsp/MiniDSP_*.txt (gains: minidsp_out1/out2_gain); not saved as a preset';
d.T_celsius   = NaN;             % not noted
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
