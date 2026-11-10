function [runs, bad] = lab_runs(datadir)
% LAB_RUNS  Every run saved in DATADIR, oldest first, each with its verdicts (m.R).
%   The large raw arrays (spec, ch, f, specn) are not loaded. Files that are not kit
%   runs or cannot be read are skipped and listed in BAD (cellstr 'name: reason').

runs = {}; bad = {};
if isempty(datadir) || ~exist(datadir, 'dir'), return; end
d = dir(fullfile(datadir, '*.mat'));
t = [];
for i = 1:numel(d)
    f = fullfile(d(i).folder, d(i).name);
    try
        v = who('-file', f);
        if ~all(ismember({'ids', 'station', 'fn', 'time'}, v))
            bad{end+1} = sprintf('%s: not a kit run', d(i).name); %#ok<AGROW>
            continue
        end
        m = load(f, v{~ismember(v, {'spec', 'ch', 'f', 'specn'})});
        [~, m.file] = fileparts(d(i).name);
        if ~isfield(m, 'note'), m.note = ''; end
        if ~isfield(m, 'label'), m.label = m.file; end
        m.R = lab_check(m);
        runs{end+1} = m; %#ok<AGROW>
        t(end+1) = datenum(m.time); %#ok<AGROW,DATNM>
    catch err
        bad{end+1} = sprintf('%s: %s', d(i).name, err.message); %#ok<AGROW>
    end
end
[~, i] = sort(t); runs = runs(i);
end
