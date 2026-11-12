function [runs, status] = lab_runs(datadir, extra)
% LAB_RUNS  Every run saved in DATADIR (oldest first), judged, + the status of every step.
%   runs{i}: the saved struct + file, path, R (verdict rows), verdict, err
%   status.<id>: verdict, time, file, msg, run (index into runs) of the LATEST run holding
%                that step. A step also carries the run-level checks it takes part in:
%                balance -> woofer and mid+tw steps, sum -> 'all', notch -> the flipped step.
%   extra (optional): cell of already-loaded runs (e.g. converted manual runs) to append;
%                they are judged and listed, but do not count in status.

runs = {};
d = dir(fullfile(datadir, '*.mat'));
for i = 1:numel(d)
    try
        m = load(fullfile(d(i).folder, d(i).name));
        if ~isfield(m, 'ids') || ~isfield(m, 'fn') || ~isfield(m, 'station'), continue; end
        [~, m.file] = fileparts(d(i).name);
        m.path = fullfile(d(i).folder, d(i).name);
        m.manual = false;
        runs{end+1} = lab_judge(m); %#ok<AGROW>
    catch e
        warning('lab:runs', 'Skipped %s: %s', d(i).name, e.message);
    end
end
if ~isempty(runs)
    [~, i] = sort(cellfun(@(m) posixtime(datetime(m.time)), runs)); runs = runs(i);
end

status = struct();
att = struct('bal', {{'S1', 'S2', 'A1', 'A2'}}, 'sum', {{'S3', 'A3', 'F0'}}, 'F1n', {{'F1'}}, 'F2n', {{'F2'}});
for i = 1:numel(runs)
    m = runs{i};
    for k = 1:numel(m.ids)
        id = m.ids{k};
        r = m.R(strcmp({m.R.id}, id));
        if isempty(r), v = {'CHECK'}; msg = ['could not be judged: ' m.err]; else, v = {r.verdict}; msg = r.msg; end
        for e = m.R(ismember({m.R.id}, fieldnames(att)'))
            if ismember(id, att.(e.id)), v{end+1} = e.verdict; msg = [msg ' | ' e.id ': ' e.msg]; end %#ok<AGROW>
        end
        status.(id) = struct('verdict', lab_worst(v), 'time', datetime(m.time), 'file', m.file, 'msg', msg, 'run', i);
    end
end

if nargin > 1
    for i = 1:numel(extra), runs{end+1} = lab_judge(extra{i}); end %#ok<AGROW>
end
end
