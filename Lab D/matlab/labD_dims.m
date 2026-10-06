function d = labD_dims()
% LABD_DIMS  Everything measured by hand in the lab. Fill in on the day.
%   NaN = not measured yet. Lengths in metres, resistances in ohm.

d.system      = 'D';
d.T_celsius   = NaN;              % not recorded on 6-Oct: the analysis assumes 20 C

% Part 1: multimeter, DC resistance of each driver
d.RE_woofer   = 5.7;
d.RE_midrange = 4.6;
d.RE_tweeter  = 3.4;
d.R_series    = 32.9;             % the resistor used (33.3 and 33.1 were the other two)

% woofer cone: diameter across the cone plus half the surround on each side
d.cone_diam   = NaN;              % TODO: written down on the day, fill in

% woofer box, INNER dimensions, no filling
d.box_inner   = [0.435 0.45 0.45];  % width, height, depth (88.1 L)

% vent tubes: inner radius, and each measured length (tag -> length, open vents)
d.vent_radius = 0.065/2;          % inner diameter 6.5 cm
d.vents = {                       % tag in data/,  tube length,  number of open vents
    'vent_L160', 0.160, 1
    'vent_L200', 0.200, 1
    'vent_L240', 0.240, 1
};

% near-field tags: cone and vent at each vent length
d.nearfield = {                   % cone tag,  vent tag,  tube length
    'nf_cone_L160', 'nf_vent_L160', 0.160
    'nf_cone_L200', 'nf_vent_L200', 0.200
    'nf_cone_L240', 'nf_vent_L240', 0.240
};

% room (for modes in the near-field data)
d.room        = [3.35 3.05 3.09];   % room 026, b.354
end
