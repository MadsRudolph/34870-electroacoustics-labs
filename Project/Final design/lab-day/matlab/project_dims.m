function d = project_dims()
% PROJECT_DIMS  Everything noted by hand on the lab day (Task 3, System D).
%   Fill in BEFORE the first run and save; measure_project stores a copy in
%   every data file. NaN / '' = not noted yet. Lengths in metres.

d.date        = '2026-11-10';
d.group       = 10;
d.system      = 'D';
d.UmikSN      = '708-0332';       % READ THE LABEL: 0329, 0332 or 0335
d.T_celsius   = NaN;              % room / chamber temperature

% Placement: keep it as in Lab E so the data line up with the model
% (Lab E: r 2.44 m, h 1.15 m, mid/tweeter box at xrel 0.12, yrel 0.29)
d.r_mic       = NaN;              % front of the boxes -> microphone
d.h_mic       = NaN;              % microphone height above the platform
d.layout      = '';               % where the mid/tweeter box sits on the woofer box
d.vents       = 'both plugged';   % guide Task 3: cover the vents in the chamber
d.filling     = 'in';
d.dust_cover  = '';

% Signal chain
d.ref_channel = 'line-out looped to line-in (before the MiniDSP)';  % CONFIRM with the TA
d.amp_volume  = '';               % knob position(s); do NOT touch between runs
d.amp_balance = '';               % both channels equal? note how it was checked
d.panel_no    = NaN;              % which passive filter panel (1-10)
d.minidsp_cfg = '';               % configuration slot / saved file name
d.minidsp_in_gain   = NaN;        % dB
d.minidsp_out1_gain = -4.5;       % dB, woofer (design value)
d.minidsp_out2_gain = 0;          % dB, mid + tweeter
d.minidsp_invert    = 'none';     % the flipW run ticks Out 1 invert: untick afterwards
d.minidsp_fs  = '';               % check the plugin says 96 kHz

% Passive board as built: nominal value, and measured if an LCR meter exists
%            part    nominal   measured   note
d.board = { 'L_mid',  0.82e-3,  NaN,      'series, amp + -> midrange +'
            'C_mid',  6.8e-6,   NaN,      'across the midrange'
            'C_tw',   5.6e-6,   NaN,      'series, amp + -> node'
            'L_tw',   0.22e-3,  NaN,      'node -> ground'
            'Rs_tw',  4.7,      NaN,      'series, node -> tweeter +'
            'Rp_tw',  3.3,      NaN,      'across the tweeter' };
d.coil_dcr    = [NaN NaN];        % ohm, L_mid and L_tw (multimeter)

% Zi/Nfield station (15-17)
d.R_series    = NaN;              % ohm, multimeter (Lab D: 32.9)
d.Rdc_board   = NaN;              % ohm, multimeter across the board input, drivers connected
d.vent1       = [0.065 0.160];    % open vent: inner diameter, length (m) -- check both
d.vent2       = [NaN NaN NaN];    % second vent: inner diameter, min and max telescope length (m)
d.vent_used   = 'vent 1 open at 160 mm, vent 2 plugged';
d.nf_mic_dist = NaN;              % mic to dust cap / vent mouth (m)
d.notes       = '';
end
