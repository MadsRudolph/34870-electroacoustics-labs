function p = labpaths(add)
% LABPATHS  Every folder the lab-day scripts use, worked out in one place.
%
%   p = labpaths          struct of absolute paths (no '..' in them)
%   labpaths('all')       also puts every code folder on the MATLAB path
%
%   lab-day/                    p.root
%     kit/  kit/core/           p.kit, p.kitcore          (GUI + lab commands)
%     manual/  manual/core/     p.manual, p.manualcore    (Tuesday's section scripts)
%     analysis/                 p.analysis                (after-the-lab scripts)
%     data/                     p.data      (data/<date>/ = one lab day of the kit)
%     demo_data/                p.demo      (labgui demo mode only, not in git)
%     model/  figures/          p.model, p.figures
%   Final design/               p.final     (design/design.json, data/dsp/*.txt)
%   Labs/                       p.labs
%     Lab D/ (matlab, data, matlab/course)   p.labD, p.labDmatlab, p.labDdata, p.labDcourse
%     Lab E/matlab/course                    p.labEcourse

core = fileparts(mfilename('fullpath'));
p.kitcore    = core;
p.kit        = fileparts(core);
p.root       = fileparts(p.kit);
p.manual     = fullfile(p.root, 'manual');
p.manualcore = fullfile(p.manual, 'core');
p.analysis   = fullfile(p.root, 'analysis');
p.data       = fullfile(p.root, 'data');
p.demo       = fullfile(p.root, 'demo_data');
p.model      = fullfile(p.root, 'model');
p.figures    = fullfile(p.root, 'figures');
p.final      = fileparts(p.root);
p.labs       = fileparts(fileparts(p.final));
p.labD       = fullfile(p.labs, 'Lab D');
p.labDmatlab = fullfile(p.labD, 'matlab');
p.labDdata   = fullfile(p.labD, 'data');
p.labDcourse = fullfile(p.labD, 'matlab', 'course');
p.labEcourse = fullfile(p.labs, 'Lab E', 'matlab', 'course');

if nargin && strcmpi(add, 'all')
    addpath(p.kit, p.kitcore, p.manual, p.manualcore, p.labDmatlab);
end
end
