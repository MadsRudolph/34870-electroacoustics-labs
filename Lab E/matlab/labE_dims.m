function d = labE_dims()
% LABE_DIMS  Everything measured by hand in Lab E. Fill in on the day.
%   NaN = not measured yet. Lengths in metres.

d.system      = 'D';
d.UmikSN      = '708-0332';       % as used in labE_run
d.T_celsius   = NaN;              % room temperature (sets c)

% Part 1: the 3" driver
% effective diameter = across the cone plus half the surround on each side
d.diam_3in    = NaN;              % rule of thumb: radius in cm ~ 3 -> 0.06 m
d.r_mic_1     = NaN;              % microphone distance from the driver
d.circle_radius = NaN;            % circular screen radius
d.iec_size    = [NaN NaN];        % IEC screen width, height
d.iec_driver  = [NaN NaN];        % driver centre measured from the screen's
                                  % LEFT and BOTTOM edge (seen from the mic)

% Part 2: the project system
d.diam_woofer   = 0.211;          % Scan-Speak 26W/8534G00 data sheet (Lab D)
d.diam_midrange = NaN;
d.diam_tweeter  = NaN;
d.r_mic_2     = NaN;              % rough distance speaker -> microphone
d.h_mic_2     = NaN;              % microphone height above the platform
d.layout      = '';               % where the mid/tweeter box sits on the woofer box
d.dust_cover  = '';               % kept on or taken off
end
