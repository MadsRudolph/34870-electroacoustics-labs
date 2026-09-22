% IMPORT_GROUP_FILES  Build the labB_<tag>.mat files that process_labB expects from the files the group
% saved on the lab PC (22-Sep-2026).  On the day the course script labB.m was used instead of
% measure_labB, so each file holds only  h = specn(:,2)./specn(:,1)  (UMIK / line-in, UMIK-corrected)
% and nothing else: no frequency vector, no raw spectra, no metadata.  The frequency vector is
% reconstructed from the multitone generator with the lab-sheet parameters (deterministic: only the
% phases are random) and the timestamp is taken from the file.  The originals in
% data/Lab B master group 10/ are never touched; the labB_*.mat files are derived copies.
%
%   mockup_<deg>.mat     -> labB_ang<deg>.mat          (mock-up at <deg>, mic at the series distance)
%   no_mockup_1.8m.mat   -> labB_nomockup.mat          reference for the series (same mic position)
%   no_mockup_1.8m.mat   -> labB_dist280cm.mat  \      (the file name is a typo from the lab PC: the tape said 2.8 m,
%   no_mockup_1.4m.mat   -> labB_dist140cm.mat   |      and 0.93 -> 2.8 m gives the -9.6 dB that 1/r predicts)
%   no_mockup_0.93.mat   -> labB_dist93cm.mat   /      Part 0: free-field (1/r) check
%   test.mat             -> (skipped: trial run before the series, does not match any reference)
here = fileparts(mfilename('fullpath')); dataDir = fullfile(here, '..', 'data'); src = fullfile(dataDir, 'Lab B master group 10');
addpath(fullfile(here, 'course'));
P = struct('f1', 50, 'f2', 10000, 'n_oct', 24, 'fres', 1, 'Nav', 32, 'IncAngle', 90);   % labB.m on the lab PC
UmikSN = '708-0332';                                                                     % labB.m on the lab PC
[~, ~, fn] = createMultitone_w(48000, P.f1, P.f2, P.n_oct, P.fres, 3.5, 0.1); fn = fn(:);

map = {'mockup_0', 'ang000'; 'mockup_15', 'ang015'; 'mockup_30', 'ang030'; 'mockup_45', 'ang045'; ...
       'mockup_60', 'ang060'; 'mockup_75', 'ang075'; 'mockup_90', 'ang090'; ...
       'no_mockup_1.8m', 'nomockup'; 'no_mockup_1.8m', 'dist280cm'; 'no_mockup_1.4m', 'dist140cm'; 'no_mockup_0.93', 'dist93cm'};
notes = containers.Map({'nomockup', 'dist280cm', 'dist140cm', 'dist93cm'}, ...
    {'no mock-up, mic at the series position (2.8 m from the loudspeaker; the lab-PC file name says 1.8m, the tape said 2.8), taken AFTER the angle series', ...
     'Part 0: no mock-up, 2.8 m (same file as the reference)', 'Part 0: no mock-up, mic moved to 1.4 m', 'Part 0: no mock-up, mic moved to 0.93 m'});
for k = 1:size(map, 1)
    s = dir(fullfile(src, [map{k, 1} '.mat'])); m = load(fullfile(src, s.name));
    assert(numel(m.h) == numel(fn), '%s: %d points, generator gives %d', s.name, numel(m.h), numel(fn));
    H = m.h(:); tag = map{k, 2};
    if isKey(notes, tag), note = notes(tag); else, note = sprintf('mock-up at %d deg, mic 2.8 m from the loudspeaker', sscanf(tag, 'ang%d')); end
    meta = struct('tag', tag, 'UmikSN', UmikSN, 'note', note, 'time', datestr(s.datenum, 31), 'params', P, ...
                  'source', ['Lab B master group 10/' s.name], 'imported', datestr(now, 31)); %#ok<TNOW1,DATST>
    save(fullfile(dataDir, ['labB_' tag '.mat']), 'fn', 'H', 'meta');
    fprintf('%-16s <- %-20s  %s  %s\n', ['labB_' tag '.mat'], s.name, meta.time, note);
end
