function P = lab_plan()
% LAB_PLAN  Every step the kit knows. Add a step = add one line here.
%
%   id       what you type: lab('P1')
%   grp      a run of up to 3 steps measured in ONE go (shared phase): lab('S')
%   station  'chamber' (UMIK, sound card) or 'zinf' (NI card, Lab D setup)
%   model    chamber: column in ../model/expected_*.csv; zinf: board/woofer/nearfield
%   angle    0 or 30 (chamber)
%   dsp      'bypass' or 'on' (what the MiniDSP must be set to)
%   setup    what to do BEFORE pressing Measure
%   band     frequency band the verdict is judged in (Hz)

c = {
% id   grp  station    model         angle dsp       band          title / setup
'P1'  'P'  'chamber'  'byp_woofer'   0  'bypass'  [150 5000]   'Placement: woofer'               'MiniDSP BYPASSED. Pull the amp ch. 2 speaker cable (mid + tweeter silent).'
'P2'  'P'  'chamber'  'byp_mid'      0  'bypass'  [200 5000]   'Placement: midrange (via board)' 'MiniDSP BYPASSED. Pull the amp ch. 1 cable (woofer silent). TWEETER lead off at the board.'
'P3'  'P'  'chamber'  'byp_tw'       0  'bypass'  [2000 18000] 'Placement: tweeter (via board)'  'MiniDSP BYPASSED. Amp ch. 1 cable pulled. MIDRANGE lead off, tweeter lead on.'
'P2d' ''   'chamber'  'dir_mid'      0  'bypass'  [200 5000]   'Midrange wired straight (no board)' 'MiniDSP BYPASSED. Amp ch. 1 pulled. Midrange wired DIRECTLY to amp ch. 2 (board out of the path).'
'P3d' ''   'chamber'  'dir_tw'       0  'bypass'  [2000 18000] 'Tweeter wired straight (no board)'  'MiniDSP BYPASSED. Amp ch. 1 pulled. Tweeter wired DIRECTLY to amp ch. 2 (board out of the path).'
'S1'  'S'  'chamber'  'woofer'       0  'on'      [100 250]    'System: woofer only'             'MiniDSP ON (filters pasted, Out 1/Out 2 gains as in today''s settings). Pull the amp ch. 2 cable.'
'S2'  'S'  'chamber'  'midtw'        0  'on'      [600 15000]  'System: mid + tweeter'           'Plug ch. 2 back, pull the amp ch. 1 cable.'
'S3'  'S'  'chamber'  'all'          0  'on'      [150 15000]  'System: all three'               'Plug ch. 1 back. Everything on, normal polarity.'
'S4'  ''   'chamber'  'mid'          0  'on'      [600 2500]   'System: midrange only'           'MiniDSP ON. Amp ch. 1 pulled. TWEETER lead off at the board.'
'S5'  ''   'chamber'  'tw'           0  'on'      [5000 15000] 'System: tweeter only'            'MiniDSP ON. Amp ch. 1 pulled. MIDRANGE lead off, tweeter lead on.'
'F0'  'F'  'chamber'  'all'          0  'on'      [150 15000]  'Flip: all (reference)'           'Everything on, normal polarity.'
'F1'  'F'  'chamber'  'flipW'        0  'on'      [1000 15000] 'Flip: woofer inverted'           'Tick Out 1 INVERT in the MiniDSP app.'
'F2'  'F'  'chamber'  'flipT'        0  'on'      [150 1500]   'Flip: tweeter swapped'           'UNtick Out 1 invert. Swap the tweeter + and - at the board. (Swap back afterwards!)'
'A1'  'A'  'chamber'  'woofer'      30  'on'      [100 250]    '30 deg: woofer only'             'System turned 30 deg (as Lab E). Pull the amp ch. 2 cable.'
'A2'  'A'  'chamber'  'midtw'       30  'on'      [600 15000]  '30 deg: mid + tweeter'           'Plug ch. 2 back, pull ch. 1.'
'A3'  'A'  'chamber'  'all'         30  'on'      [150 15000]  '30 deg: all three'               'Plug ch. 1 back.'
'Z1'  ''   'zinf'     'board'        0  ''        [50 19000]   'Impedance: board input'          'Amp -> series R -> board input, both drivers connected.'
'Z2'  ''   'zinf'     'board_mid'    0  ''        [50 19000]   'Impedance: board, mid branch'    'TWEETER lead off at the board.'
'Z3'  ''   'zinf'     'board_tw'     0  ''        [50 19000]   'Impedance: board, tweeter branch' 'MIDRANGE lead off at the board (tweeter lead back on).'
'Z4'  ''   'zinf'     'woofer'       0  ''        [5 200]      'Impedance: woofer in the box'    'Series R -> woofer. One vent open at lab_setup().vent_mm, the other plugged.'
'N1'  ''   'zinf'     'nf_cone'      0  ''        [10 200]     'Near field: cone'                'Series R SHORTED. Mic ~1 cm from the dust cap. Nexus on, 1 V/Pa.'
'N2'  ''   'zinf'     'nf_vent'      0  ''        [10 200]     'Near field: vent'                'Series R SHORTED. Mic at the vent mouth.'
};
P = cell2struct(c, {'id','grp','station','model','angle','dsp','band','title','setup'}, 2);
end
