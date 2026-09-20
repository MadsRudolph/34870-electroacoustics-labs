% Run the course BEM model (CylinderPlaneWave) for a set of incidence angles and both
% back-end geometries, and store everything in bem_results.mat / bem_results.csv.
% The package itself (BEM_FreeField.zip from DTU Learn, 106 MB of pre-computed matrices)
% is unpacked into ./package and is not committed.
%
%   cd 'Lab B/bem'; matlab -batch run_bem
here = fileparts(mfilename('fullpath'));
cd(fullfile(here, 'package'));
angles = [0 15 30 45 60 75 90 120 150 180];          % degrees, mock-up axis vs. incidence
ends   = {'Round', 'Flat'};
res = struct();
for e = 1:numel(ends)
    for a = 1:numel(angles)
        tic
        [fr, pc, pfp, pav] = CylinderPlaneWave(angles(a)*pi/180, ends{e}, 'no');
        close all
        res.(ends{e}).p_centre(a, :) = pc;
        res.(ends{e}).p_FP(a, :)     = pfp;          % default field point: on axis, 3 cm in front of the face
        res.(ends{e}).p_avg(a, :)    = pav;          % parabolic-weighted average over the face
        fprintf('%s end, %3d deg: %.1f s\n', ends{e}, angles(a), toc);
    end
end
res.fr = fr; res.angles = angles; res.R = 0.125; res.L_total = 0.855;
cd(here); save('bem_results.mat', '-struct', 'res');
% flat CSV for Python / the study site: f, then |p| in dB for every (end, quantity, angle)
T = table(fr(:), 'VariableNames', {'f_Hz'});
for e = 1:numel(ends)
    for q = {'p_centre', 'p_FP', 'p_avg'}
        for a = 1:numel(angles)
            T.(sprintf('%s_%s_%ddeg_dB', ends{e}, q{1}, angles(a))) = 20*log10(abs(res.(ends{e}).(q{1})(a, :)))';
        end
    end
end
writetable(T, 'bem_results.csv');
