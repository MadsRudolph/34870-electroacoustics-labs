function m = lab_convert(file)
% LAB_CONVERT  A run made with the 10-Nov scripts (project_*.mat / zinf_*.mat) -> the kit's
%   format, in memory only: the original file is only read, nothing is written.
%   (analysis/labday_to_kit.m does the same for the 10-Nov day, with hand-picked labels.)
%
%   states -> steps:  woofer/midtw/all at 0 deg = S1/S2/S3, at 30 deg = A1/A2/A3,
%                     mid = S4, tw = S5; in a flip run all/flipW/flipT = F0/F1/F2
%   zinf:             board = Z1 (tag with 'mid' = Z2, 'tw' = Z3), woofer = Z4,
%                     nearfield = N1 (tag with 'vent' = N2)

s = load(file);
[~, name] = fileparts(file);
S = lab_setup();
S.date = char(datetime(s.time, 'Format', 'yyyy-MM-dd'));
note = '';
if isfield(s, 'note'), note = char(s.note); end
if isfield(s, 'problem') && ~isempty(s.problem), note = strtrim([note ' PROBLEM: ' char(s.problem)]); end
if isfield(s, 'dims')
    d = s.dims;
    if isfield(d, 'minidsp_out1_gain'), S.out1_gain = d.minidsp_out1_gain; end
    if isfield(d, 'minidsp_out2_gain'), S.out2_gain = d.minidsp_out2_gain; end
    if isfield(d, 'amp_volume'), S.amp_volume = d.amp_volume; end
    if isfield(d, 'T_celsius'), S.T_celsius = d.T_celsius; end
end
if isfield(s, 'states') && isfield(s, 'H')
    flip = any(ismember(s.states, {'flipW', 'flipT'}));
    ids = cell(1, numel(s.states));
    for k = 1:numel(s.states)
        switch s.states{k}
            case 'woofer', a = {'S1', 'A1'};
            case 'midtw',  a = {'S2', 'A2'};
            case 'all',    if flip, a = {'F0', ''}; else, a = {'S3', 'A3'}; end
            case 'mid',    a = {'S4', ''};
            case 'tw',     a = {'S5', ''};
            case 'flipW',  a = {'F1', ''};
            case 'flipT',  a = {'F2', ''};
            otherwise,     a = {'', ''};
        end
        ids{k} = a{1 + (s.angle_deg == 30)};
        assert(~isempty(ids{k}), 'No step in the plan for state "%s" at %g deg.', s.states{k}, s.angle_deg);
    end
    if isfield(s, 'UmikSN'), S.UmikSN = s.UmikSN; end
    m = struct('label', name, 'ids', {ids}, 'station', 'chamber', 'angle', s.angle_deg, 'dsp', 'on', ...
        'setup', S, 'note', note, 'time', s.time, 'fn', s.fn(:), 'H', s.H, 'peak', s.peak, 'Nav', s.Nav);
elseif isfield(s, 'kind')
    tag = ''; if isfield(s, 'tag'), tag = char(s.tag); end
    t = regexp([tag ' ' name], 'L(\d{2,3})(?!\d)', 'tokens', 'once');
    if ~isempty(t), S.vent_mm = str2double(t{1}); elseif isfield(s, 'L_vent'), S.vent_mm = round(1000*s.L_vent); end
    if isfield(s, 'R'), S.R_series = s.R; end
    if isfield(s, 'NexusVperPa'), S.NexusVperPa = s.NexusVperPa; end
    switch s.kind
        case 'board'
            if contains(tag, 'mid'), id = 'Z2'; elseif contains(tag, 'tw'), id = 'Z3'; else, id = 'Z1'; end
        case 'woofer',    id = 'Z4';
        case 'nearfield', if contains([tag name], 'vent'), id = 'N2'; else, id = 'N1'; end
        otherwise, error('Unknown kind "%s" in %s.', s.kind, name);
    end
    m = struct('label', name, 'ids', {{id}}, 'station', 'zinf', 'angle', 0, 'dsp', '', ...
        'setup', S, 'note', note, 'time', s.time, 'fn', s.fn(:), 'Nav', s.Nav);
    if isfield(s, 'Z'), m.Z = s.Z(:); else, m.H = s.H(:); end
    for f = {'k_amp', 'dc_AI0', 'clip', 'peak'}
        if isfield(s, f{1}), m.(f{1}) = s.(f{1}); end
    end
else
    error('%s is not a project_*.mat or zinf_*.mat file from the lab scripts.', name);
end
m.file = name; m.path = file; m.src = file; m.manual = true;
end
