function P = lab_plan()
% LAB_PLAN  Every step the kit knows. Add a step = add one line here.
%
%   id       what you type: lab('P1')
%   grp      a run of up to 3 steps measured in ONE go (shared phase): lab('S')
%   station  'chamber' (UMIK, sound card) or 'zinf' (NI card, Lab D setup)
%   model    chamber: column in ../model/expected_*.csv; zinf: board/woofer/nearfield
%   angle    0 or 30 (chamber)
%   dsp      'bypass' or 'on' (what the MiniDSP must be set to)
%   sw       chamber: which units are ON on the switchboard (W woofer, M midrange, T tweeter),
%            e.g. 'W', 'MT', 'WMT'. The states are made THERE (as in Lab E): no cable is
%            pulled, nothing is muted in the MiniDSP, no lead is lifted.
%   setup    what else to do BEFORE pressing Measure (the switchboard text is made from sw)
%   band     frequency band the verdict is judged in (Hz)

c = {
% id   grp  station    model         angle dsp       band          sw     title / setup (what to do besides the switchboard)
'P1'  'P'  'chamber'  'byp_woofer'   0  'bypass'  [150 5000]   'W'    'Placement: woofer'               'MiniDSP BYPASSED.'
'P2'  'P'  'chamber'  'byp_mid'      0  'bypass'  [200 5000]   'M'    'Placement: midrange (via board)' 'MiniDSP BYPASSED.'
'P3'  'P'  'chamber'  'byp_tw'       0  'bypass'  [2000 18000] 'T'    'Placement: tweeter (via board)'  'MiniDSP BYPASSED.'
'P2d' ''   'chamber'  'dir_mid'      0  'bypass'  [200 5000]   'M'    'Midrange wired straight (no board)' 'OPTIONAL, only if the board can be bypassed. MiniDSP BYPASSED. Midrange wired DIRECTLY to the amplifier (board out of the path).'
'P3d' ''   'chamber'  'dir_tw'       0  'bypass'  [2000 18000] 'T'    'Tweeter wired straight (no board)'  'OPTIONAL, only if the board can be bypassed. MiniDSP BYPASSED. Tweeter wired DIRECTLY to the amplifier (board out of the path).'
'S1'  'S'  'chamber'  'woofer'       0  'on'      [100 250]    'W'    'System: woofer only'             'MiniDSP ON (Out 1 gain as in lab_setup).'
'S2'  'S'  'chamber'  'midtw'        0  'on'      [600 15000]  'MT'   'System: mid + tweeter'           ''
'S3'  'S'  'chamber'  'all'          0  'on'      [150 15000]  'WMT'  'System: all three'               'Normal polarity.'
'S4'  ''   'chamber'  'mid'          0  'on'      [600 2500]   'M'    'System: midrange only'           'MiniDSP ON.'
'S5'  ''   'chamber'  'tw'           0  'on'      [5000 15000] 'T'    'System: tweeter only'            'MiniDSP ON.'
'F0'  'F'  'chamber'  'all'          0  'on'      [150 15000]  'WMT'  'Flip: all (reference)'           'Normal polarity (Out 1 invert NOT ticked).'
'F1'  'F'  'chamber'  'flipW'        0  'on'      [1000 15000] 'WMT'  'Flip: woofer inverted'           'Tick Out 1 INVERT in the MiniDSP app.'
'F2'  'F'  'chamber'  'flipT'        0  'on'      [150 1500]   'WMT'  'Flip: tweeter swapped'           'UNtick Out 1 invert. Swap tweeter + / - at the board.'
'A1'  'A'  'chamber'  'woofer'      30  'on'      [100 250]    'W'    '30 deg: woofer only'             'System turned 30 deg (as Lab E). MiniDSP ON.'
'A2'  'A'  'chamber'  'midtw'       30  'on'      [600 15000]  'MT'   '30 deg: mid + tweeter'           ''
'A3'  'A'  'chamber'  'all'         30  'on'      [150 15000]  'WMT'  '30 deg: all three'               'Normal polarity.'
'Z1'  ''   'zinf'     'board'        0  ''        [50 19000]   ''     'Impedance: board input'          'Amp -> series R -> board input, midrange and tweeter both connected (both ON if the switchboard is in the path).'
'Z2'  ''   'zinf'     'board_mid'    0  ''        [50 19000]   ''     'Impedance: board, mid branch'    'Switch the TWEETER OFF on the switchboard (or lift its lead at the board).'
'Z3'  ''   'zinf'     'board_tw'     0  ''        [50 19000]   ''     'Impedance: board, tweeter branch' 'Switch the MIDRANGE OFF on the switchboard (or lift its lead); tweeter back ON.'
'Z4'  ''   'zinf'     'woofer'       0  ''        [5 200]      ''     'Impedance: woofer in the box'    'Series R -> woofer. One vent open at lab_setup().vent_mm, the other plugged.'
'N1'  ''   'zinf'     'nf_cone'      0  ''        [10 200]     ''     'Near field: cone'                'Series R SHORTED. Mic ~1 cm from the dust cap. Nexus on, 1 V/Pa.'
'N2'  ''   'zinf'     'nf_vent'      0  ''        [10 200]     ''     'Near field: vent'                'Series R SHORTED. Mic at the vent mouth.'
};
P = cell2struct(c, {'id','grp','station','model','angle','dsp','band','sw','title','setup'}, 2);
end
