function [S, G] = lab_settings(datadir, S, G)
% LAB_SETTINGS  The session's settings: lab_setup.m plus what was changed in the GUI today.
%
%   S = lab_settings(datadir)      lab_setup() overlaid with <datadir>/settings.json (if any)
%   lab_settings(datadir, S)       store S in <datadir>/settings.json (survives a restart)
%   [S, G] = lab_settings(datadir) / lab_settings(datadir, S, G)
%       G = the GUI's own choices (G.theme = 'light' | 'dark'), kept in the same file
%       under gui_*; they are not part of S, so they are not stored in the measurements.
%
% The file is plain text (JSON) next to the day's data, so it travels with the data.
% Only fields that exist in lab_setup.m are read back; the date is never taken from it.

file = fullfile(datadir, 'settings.json');
if nargin > 1
    if ~exist(datadir, 'dir'), mkdir(datadir); end
    fid = fopen(file, 'w');
    assert(fid > 0, 'Cannot write %s', file);
    c = onCleanup(@() fclose(fid));
    J = S;
    if nargin > 2, for f = fieldnames(G)', J.(['gui_' f{1}]) = G.(f{1}); end, end
    try, txt = jsonencode(J, 'PrettyPrint', true); catch, txt = jsonencode(J); end
    fprintf(fid, '%s\n', txt);
    return
end
S = lab_setup();
G = struct('theme', 'light');
if ~exist(file, 'file'), return; end
try
    J = jsondecode(fileread(file));
catch
    warning('lab:settings', 'Could not read %s: using lab_setup.m.', file); return
end
if isfield(J, 'gui_theme') && ischar(J.gui_theme) && any(strcmp(J.gui_theme, {'light', 'dark'})), G.theme = J.gui_theme; end
for f = fieldnames(S)'
    n = f{1};
    if strcmp(n, 'date') || ~isfield(J, n), continue; end
    v = J.(n);
    if isnumeric(S.(n))
        if isempty(v), v = NaN; end              % JSON null = NaN
        if isnumeric(v) && isscalar(v), S.(n) = double(v); end
    elseif ischar(S.(n))
        if isempty(v), v = ''; end
        if ischar(v), S.(n) = v; end
    end
end
end
