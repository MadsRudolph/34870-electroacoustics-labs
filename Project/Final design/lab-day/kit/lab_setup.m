function s = lab_setup()
% LAB_SETUP  The session's settings: EDIT THESE at the start of the day.
%   Stored in every measurement file, so the data say how they were taken.

s.date        = char(datetime('today', 'Format', 'yyyy-MM-dd'));  % data go to ../data/<date>/
s.group       = 10;
s.UmikSN      = '708-0332';      % read the label on the UMIK
s.amp_volume  = 'about 45 %';    % do not touch during the session
s.out1_gain   = -5.8;            % MiniDSP Out 1 (woofer), dB: design -4.5; -5.8 balanced the lab amplifier on 10-Nov
s.out2_gain   = 0;               % MiniDSP Out 2 (mid + tweeter), dB
s.vent_mm     = 160;             % open vent length (design: 160). Plugged in the chamber anyway.
s.R_series    = NaN;             % Zi station: series resistor, MULTIMETER value (about 32.9)
s.NexusVperPa = 1;               % Zi station, near field
s.placement   = 'as Lab E: mic 2.44 m, 1.15 m high';
s.T_celsius   = NaN;
s.notes       = '';
s.gui_theme   = 'light';         % labgui colours, 'light' or 'dark' (the GUI's Colours menu sets it)
end
