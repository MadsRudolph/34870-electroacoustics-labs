function [S, src] = lab_settings(datadir, S)
% LAB_SETTINGS  The settings in force for one lab day.
%
%   [S, src] = lab_settings(datadir)   lab_setup.m, with <datadir>/session.json on top
%                                      when it exists (labgui writes it). src says which.
%   lab_settings(datadir, S)           save S as <datadir>/session.json
%
%   So the GUI and the lab commands share one set of settings for the day: change a
%   value in the GUI and 'lab S' uses it too. S.date always follows the folder name
%   when that is a date (data/2026-11-12 -> '2026-11-12').

f = fullfile(datadir, 'session.json');
if nargin >= 2                                       % ---- save
    if ~exist(datadir, 'dir'), mkdir(datadir); end
    J = S;
    for k = fieldnames(J)'
        v = J.(k{1});
        if isnumeric(v) && isscalar(v) && isnan(v), J.(k{1}) = []; end   % JSON has no NaN
    end
    try, txt = jsonencode(J, 'PrettyPrint', true); catch, txt = jsonencode(J); end
    fid = fopen(f, 'w'); assert(fid > 0, 'Cannot write %s', f);
    fprintf(fid, '%s\n', txt); fclose(fid);
    src = f;
    return
end

S = lab_setup(); src = 'lab_setup.m';
if exist(f, 'file')
    try
        J = jsondecode(fileread(f));
        for k = fieldnames(J)'
            if ~isfield(S, k{1}) || strcmp(k{1}, 'date'), continue; end
            v = J.(k{1});
            if isnumeric(S.(k{1}))
                if isempty(v), v = NaN; end
                v = double(v);
            elseif ~ischar(v)
                v = char(string(v));
            end
            S.(k{1}) = v;
        end
        src = 'session.json';
    catch err
        warning('lab:settings', 'Could not read %s (%s): using lab_setup.m.', f, err.message);
    end
end
[~, day] = fileparts(datadir);
if ~isempty(regexp(day, '^\d{4}-\d{2}-\d{2}$', 'once')), S.date = day; end
end
