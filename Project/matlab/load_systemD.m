function S = load_systemD()
% S = load_systemD()
%
% Loads the System D measurements the project builds on:
%   Lab D (6 Oct): input impedances and the woofer near-field responses
%   Lab E (20 Oct): anechoic transfer functions p/V of the three units
%
% Output struct (all frequency vectors in Hz, responses complex):
%   S.Zi.<unit>.f, .Z        unit = woofer_free, woofer_closed, midrange, tweeter
%   S.Zi.vent_L160/L200/L240 woofer in the box with one vent of that length (mm)
%   S.TF.f                   frequency vector of the Lab E system runs
%   S.TF.on.<unit>           p/V at 0 deg,  unit = woofer, midrange, tweeter
%   S.TF.off30.<unit>        p/V at 30 deg
%   S.NF.cone_L<len>, .vent_L<len>   near-field H with .f (woofer box, Lab D)
%
% Z already uses R = 32.9 ohm and V_amp = 2*AI0 (see Lab D/README.md), so it
% can go straight into Matlab2LTspice. The three Lab E units come from one
% run each (vent plugged), so their relative phase is valid. Use the same
% distance d for all three when calling Matlab2LTspice.
%
% Example (from Project/matlab):
%   S = load_systemD;
%   addpath course
%   Matlab2LTspice(S.Zi.tweeter.f, S.Zi.tweeter.Z, 'Zi_tweeter', 0);
%   Matlab2LTspice(S.TF.f, S.TF.on.tweeter, 'TF_tweeter', 1, -1.15);

here = fileparts(mfilename('fullpath'));
labs = fileparts(fileparts(here));
dD = fullfile(labs, 'Lab D', 'data');
dE = fullfile(labs, 'Lab E', 'data');

% --- Lab D: input impedances
for tag = {'woofer_free', 'woofer_closed', 'midrange', 'tweeter', ...
           'vent_L160', 'vent_L200', 'vent_L240'}
    d = load(fullfile(dD, ['labD_' tag{1} '.mat']), 'fn', 'Z');
    S.Zi.(tag{1}) = struct('f', d.fn, 'Z', d.Z);
end

% --- Lab D: near field of cone and vent for each vent length
for L = {'L160', 'L200', 'L240'}
    for part = {'cone', 'vent'}
        d = load(fullfile(dD, ['labD_nf_' part{1} '_' L{1} '.mat']), 'fn', 'H');
        S.NF.([part{1} '_' L{1}]) = struct('f', d.fn, 'H', d.H);
    end
end

% --- Lab E: H(:,1..3) = woofer, midrange, tweeter
units = {'woofer', 'midrange', 'tweeter'};
on  = load(fullfile(dE, 'labE_system_0.mat'),  'fn', 'H');
off = load(fullfile(dE, 'labE_system_30.mat'), 'fn', 'H');
S.TF.f = on.fn;
for k = 1:3
    S.TF.on.(units{k})    = on.H(:, k);
    S.TF.off30.(units{k}) = off.H(:, k);
end
end
