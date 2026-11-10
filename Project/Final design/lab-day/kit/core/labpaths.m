function L = labpaths()
% LABPATHS  Every folder the lab-day code uses, in ONE place (no counting of '..' elsewhere).
%
%   L = labpaths;   L.data, L.model, L.labEcourse, ...
%
% Calling it also puts the called code on the MATLAB path (kit, kit/core, matlab,
% matlab/core, Lab D/matlab), so a top-level file only needs to find this one.
% The course folders are NOT added here: the measuring code adds them only when the
% lab PC does not already have the course routine on its path.

persistent done
core = fileparts(mfilename('fullpath'));              % .../lab-day/kit/core
L.kitcore    = core;
L.kit        = fileparts(core);
L.root       = fileparts(L.kit);                      % .../lab-day
L.kittests   = fullfile(L.kit, 'tests');
L.matlab     = fullfile(L.root, 'matlab');
L.matlabcore = fullfile(L.matlab, 'core');
L.matlabtests = fullfile(L.matlab, 'tests');
L.analysis   = fullfile(L.root, 'analysis');
L.data       = fullfile(L.root, 'data');              % real data: data/<date>/ (kit), data/*.mat (10-Nov scripts)
L.demodata   = fullfile(L.root, 'demo_data');         % labgui('demo') only, never mixed with data/
L.model      = fullfile(L.root, 'model');
L.figures    = fullfile(L.root, 'figures');
L.raw        = fullfile(L.root, 'raw data');
L.results    = fullfile(L.root, 'results_2026-11-10');
L.design     = fileparts(L.root);                     % .../Project/Final design
L.repo       = fileparts(fileparts(L.design));        % .../Labs
L.labD       = fullfile(L.repo, 'Lab D');
L.labDdata   = fullfile(L.labD, 'data');
L.labDmatlab = fullfile(L.labD, 'matlab');
L.labDcourse = fullfile(L.labD, 'matlab', 'course');
L.labEcourse = fullfile(L.repo, 'Lab E', 'matlab', 'course');

if isempty(done) || ~contains([path pathsep], [L.matlabcore pathsep])
    addpath(L.kit, L.kitcore, L.matlab, L.matlabcore);
    if exist(L.labDmatlab, 'dir'), addpath(L.labDmatlab, '-end'); end   % fb_from_Z
    done = true;
end
end
