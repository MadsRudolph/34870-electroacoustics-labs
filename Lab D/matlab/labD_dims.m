function d = labD_dims()
% LABD_DIMS  Everything measured by hand in the lab. Fill in on the day.
%   NaN = not measured yet. Lengths in metres, resistances in ohm.

d.system      = 'D';
d.T_celsius   = NaN;              % room temperature (sets c)

% Part 1: multimeter, DC resistance of each driver
d.RE_woofer   = NaN;
d.RE_midrange = NaN;
d.RE_tweeter  = NaN;
d.R_series    = 33;               % measure the actual resistor too

% woofer cone: diameter across the cone plus half the surround on each side
d.cone_diam   = NaN;

% woofer box, INNER dimensions, no filling
d.box_inner   = [NaN NaN NaN];    % width, height, depth

% vent tubes: inner radius, and each measured length (tag -> length, open vents)
d.vent_radius = NaN;
d.vents = {                       % tag in data/,  tube length,  number of open vents
%   'vent_L1',   0.050, 1
%   'vent_L2',   0.100, 1
%   'vent_L3',   0.150, 1
};

% near-field tags: cone and vent at each vent length
d.nearfield = {                   % cone tag,  vent tag,  tube length
%   'nf_cone_L1', 'nf_vent_L1', 0.050
};

% room (for modes in the near-field data)
d.room        = [NaN NaN NaN];
end
