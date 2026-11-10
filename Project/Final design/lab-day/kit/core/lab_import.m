function [made, msgs] = lab_import(datadir, files)
% LAB_IMPORT  Runs measured by hand with Tuesday's scripts -> the kit's day folder, so the
%   GUI and the dashboard show them too ("Load manual runs" in labgui).
%
%   [made, msgs] = lab_import(datadir)          every lab-day/data/project_*.mat and zinf_*.mat
%                                               measured on the day of DATADIR, not imported yet
%   [made, msgs] = lab_import(datadir, files)   these files (cellstr of full paths)
%   made = new kit files (full paths); msgs = one line per source file (what happened).
%
%   The source files are only read, never changed. Each import is a NEW file
%   <datadir>/manual_<tag>.mat with m.src = the source file name; a source already
%   imported into this folder is skipped. Mapping (as labday_to_kit did for 10-Nov):
%     chamber states  woofer/midtw/all -> S1/S2/S3 (A1/A2/A3 at 30 deg), mid -> S4, tw -> S5,
%                     in a run with flipW/flipT: all -> F0, flipW -> F1, flipT -> F2
%     zinf            board -> Z1 (tag with 'mid' -> Z2, 'tw' -> Z3), woofer -> Z4,
%                     nearfield -> N1 (tag with 'vent' -> N2)

L = labpaths();
made = {}; msgs = {};
[~, day] = fileparts(datadir);
if nargin < 2 || isempty(files)
    d = [dir(fullfile(L.data, 'project_*.mat')); dir(fullfile(L.data, 'zinf_*.mat'))];
    files = {};
    for i = 1:numel(d)
        f = fullfile(d(i).folder, d(i).name);
        try
            w = load(f, 'time');
            if strcmp(char(datetime(w.time, 'Format', 'yyyy-MM-dd')), day), files{end+1} = f; end %#ok<AGROW>
        catch
        end
    end
    if isempty(files), msgs{end+1} = sprintf('No manual runs from %s in %s.', day, L.data); return; end
end
files = cellstr(files);

done = {};                                         % sources already imported here
for r = lab_runs(datadir)
    if isfield(r{1}, 'src'), done{end+1} = r{1}.src; end %#ok<AGROW>
end
if ~exist(datadir, 'dir'), mkdir(datadir); end

for i = 1:numel(files)
    [~, nm, ext] = fileparts(files{i}); src = [nm ext];
    if any(strcmp(done, src)) || any(strcmp(done, nm))
        msgs{end+1} = sprintf('%s: already imported, skipped', src); continue %#ok<AGROW>
    end
    try
        s = load(files{i});
        if isfield(s, 'used') && ~s.used
            why = ''; if isfield(s, 'problem'), why = s.problem; end
            msgs{end+1} = sprintf('%s: marked as not used (%s), skipped', src, why); continue %#ok<AGROW>
        end
        if isfield(s, 'states'), k = chamber(s); else, k = zinf(s); end
        if isempty(k), msgs{end+1} = sprintf('%s: no kit step matches, skipped', src); continue; end %#ok<AGROW>
        k.src = src;
        k.setup = setup_from(s, k);
        tag = erase(nm, {'project_', 'zinf_'});
        out = fullfile(datadir, ['manual_' tag '.mat']); n = 2;
        while exist(out, 'file'), out = fullfile(datadir, sprintf('manual_%s_%d.mat', tag, n)); n = n + 1; end
        save(out, '-struct', 'k');
        made{end+1} = out; %#ok<AGROW>
        msgs{end+1} = sprintf('%s -> %s as %s (%s)', src, ['manual_' tag '.mat'], k.label, strjoin(k.ids, ' ')); %#ok<AGROW>
    catch err
        msgs{end+1} = sprintf('%s: could not import (%s)', src, err.message); %#ok<AGROW>
    end
end
end

% ---------------------------------------------------------------------
function k = chamber(s)
k = [];
ang = 0; if isfield(s, 'angle_deg'), ang = s.angle_deg; end
flips = any(ismember(s.states, {'flipW', 'flipT'}));
ids = {}; keep = [];
for j = 1:numel(s.states)
    id = '';
    switch s.states{j}
        case 'woofer', id = ifelse(ang == 30, 'A1', 'S1');
        case 'midtw',  id = ifelse(ang == 30, 'A2', 'S2');
        case 'all'
            if flips, id = 'F0'; else, id = ifelse(ang == 30, 'A3', 'S3'); end
        case 'mid',    if ang == 0, id = 'S4'; end
        case 'tw',     if ang == 0, id = 'S5'; end
        case 'flipW',  id = 'F1';
        case 'flipT',  id = 'F2';
    end
    if ~isempty(id) && ~any(strcmp(ids, id)), ids{end+1} = id; keep(end+1) = j; end %#ok<AGROW>
end
if isempty(ids), return; end
P = lab_plan(); st = P(ismember({P.id}, ids));
g = unique({st.grp});
if numel(g) == 1 && ~isempty(g{1}) && sum(strcmp({P.grp}, g{1})) == numel(ids), label = g{1}; else, label = strjoin(ids, '+'); end
k = struct('label', label, 'ids', {ids}, 'station', 'chamber', 'angle', ang, 'dsp', 'on', ...
    'note', note_of(s), 'time', s.time, 'fn', s.fn(:), 'H', s.H(:, keep));
if isfield(s, 'peak'), k.peak = s.peak(:, keep); end
if isfield(s, 'Nav'), k.Nav = s.Nav; end
if isfield(s, 'specn'), k.specn = s.specn(:, :, keep); end
end

function k = zinf(s)
k = [];
if ~isfield(s, 'kind'), return; end
tag = ''; if isfield(s, 'tag'), tag = s.tag; end
switch s.kind
    case 'board'
        if contains(tag, 'mid'), id = 'Z2'; elseif contains(tag, 'tw'), id = 'Z3'; else, id = 'Z1'; end
    case 'woofer', id = 'Z4';
    case 'nearfield'
        if contains(tag, 'vent'), id = 'N2'; else, id = 'N1'; end
    otherwise, return
end
k = struct('label', id, 'ids', {{id}}, 'station', 'zinf', 'angle', 0, 'dsp', '', ...
    'note', note_of(s), 'time', s.time, 'fn', s.fn(:));
if isfield(s, 'Z'), k.Z = s.Z(:); else, k.H = s.H(:); end
for f = {'k_amp', 'dc_AI0', 'clip', 'peak', 'Nav', 'specn'}
    if isfield(s, f{1}), k.(f{1}) = s.(f{1}); end
end
end

function S = setup_from(s, k)
% the kit's settings struct, filled from what the manual file knows
S = lab_setup();
S.date = char(datetime(k.time, 'Format', 'yyyy-MM-dd'));
if isfield(s, 'UmikSN'), S.UmikSN = s.UmikSN; end
if isfield(s, 'R') && isnumeric(s.R), S.R_series = s.R; end
if isfield(s, 'NexusVperPa'), S.NexusVperPa = s.NexusVperPa; end
if isfield(s, 'dims')
    d = s.dims;
    if isfield(d, 'minidsp_out1_gain') && isfinite(d.minidsp_out1_gain), S.out1_gain = d.minidsp_out1_gain; end
    if isfield(d, 'minidsp_out2_gain') && isfinite(d.minidsp_out2_gain), S.out2_gain = d.minidsp_out2_gain; end
    if isfield(d, 'amp_volume') && ~isempty(d.amp_volume), S.amp_volume = d.amp_volume; end
    if isfield(d, 'T_celsius'), S.T_celsius = d.T_celsius; end
    if isfield(d, 'R_series') && isfinite(d.R_series) && ~(isfield(s, 'R') && isfinite(s.R)), S.R_series = d.R_series; end
    if isfield(d, 'vent1') && numel(d.vent1) >= 2 && isfinite(d.vent1(2)), S.vent_mm = round(1000*d.vent1(2)); end
end
if isfield(s, 'L_vent') && isfinite(s.L_vent), S.vent_mm = round(1000*s.L_vent); end
tag = ''; if isfield(s, 'tag'), tag = s.tag; end
t = regexp(tag, 'L(\d{2,3})(?!\d)', 'tokens', 'once');
if ~isempty(t), S.vent_mm = str2double(t{1}); end
S.notes = 'imported from a manual (Tuesday-script) run';
end

function n = note_of(s)
n = ''; if isfield(s, 'note'), n = s.note; end
if isfield(s, 'tag'), n = strtrim(sprintf('%s [manual run %s]', n, s.tag)); end
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end
