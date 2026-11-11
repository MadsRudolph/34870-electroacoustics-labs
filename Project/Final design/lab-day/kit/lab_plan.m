function P = lab_plan()
% LAB_PLAN  Every step the kit knows. Add a step = add one line here.
%
%   id       what you type: lab('P1')
%   grp      a run of up to 3 steps measured in ONE go (shared phase): lab('S')
%   station  'chamber' (UMIK, sound card) or 'zinf' (NI card, Lab D setup)
%   model    chamber: column in lab-day/model/expected_*.csv; zinf: board/woofer/nearfield
%   angle    0 or 30 (chamber)
%   dsp      'bypass' or 'on' (what the MiniDSP must be set to)
%   band     frequency band the verdict is judged in (Hz)
%   sw       chamber: the SWITCHBOARD, [woofer mid tweeter], 1 = ON, 0 = OFF. This is how the
%            states are made (as in Lab E): not by pulling amplifier cables, not by the MiniDSP
%            mute, not by lifting leads at the board. The texts "Switchboard: woofer ON, mid OFF,
%            tweeter OFF" and "during beeps 1: switch woofer OFF, mid ON" are made from it.
%   title    short name
%   setup    anything ELSE to do before this state (MiniDSP, invert, polarity, angle)

c = {
% id   grp  station    model         angle dsp       band          sw       title                                setup (besides the switchboard)
'P1'  'P'  'chamber'  'byp_woofer'   0  'bypass'  [150 5000]   [1 0 0]  'Placement: woofer'                  'MiniDSP BYPASSED.'
'P2'  'P'  'chamber'  'byp_mid'      0  'bypass'  [200 5000]   [0 1 0]  'Placement: midrange (via board)'    'MiniDSP BYPASSED.'
'P3'  'P'  'chamber'  'byp_tw'       0  'bypass'  [2000 18000] [0 0 1]  'Placement: tweeter (via board)'     'MiniDSP BYPASSED.'
'P2d' ''   'chamber'  'dir_mid'      0  'bypass'  [200 5000]   [0 1 0]  'Optional: midrange, no board'         'OPTIONAL, check on the day: only if the switchboard/panel can bypass the board. MiniDSP BYPASSED, midrange straight to the amplifier.'
'P3d' ''   'chamber'  'dir_tw'       0  'bypass'  [2000 18000] [0 0 1]  'Optional: tweeter, no board'         'OPTIONAL, check on the day: only if the switchboard/panel can bypass the board. MiniDSP BYPASSED, tweeter straight to the amplifier.'
'S1'  'S'  'chamber'  'woofer'       0  'on'      [100 250]    [1 0 0]  'System: woofer only'                'MiniDSP ON (filters pasted, Out 1/Out 2 gains as in today''s settings, invert off).'
'S2'  'S'  'chamber'  'midtw'        0  'on'      [600 15000]  [0 1 1]  'System: mid + tweeter'              ''
'S3'  'S'  'chamber'  'all'          0  'on'      [150 15000]  [1 1 1]  'System: all three'                  'Normal polarity.'
'S4'  ''   'chamber'  'mid'          0  'on'      [600 2500]   [0 1 0]  'System: midrange only'              'MiniDSP ON.'
'S5'  ''   'chamber'  'tw'           0  'on'      [5000 15000] [0 0 1]  'System: tweeter only'               'MiniDSP ON.'
'F0'  'F'  'chamber'  'all'          0  'on'      [150 15000]  [1 1 1]  'Flip: all (reference)'              'MiniDSP ON, Out 1 invert off, normal polarity.'
'F1'  'F'  'chamber'  'flipW'        0  'on'      [1000 15000] [1 1 1]  'Flip: woofer inverted'              'Tick Out 1 INVERT in the MiniDSP app.'
'F2'  'F'  'chamber'  'flipT'        0  'on'      [150 1500]   [1 1 1]  'Flip: tweeter swapped'              'UNtick Out 1 invert. Swap the tweeter + and - at the board (swap it back afterwards!).'
'A1'  'A'  'chamber'  'woofer'      30  'on'      [100 250]    [1 0 0]  '30 deg: woofer only'                'System turned 30 deg (as Lab E). MiniDSP ON.'
'A2'  'A'  'chamber'  'midtw'       30  'on'      [600 15000]  [0 1 1]  '30 deg: mid + tweeter'              ''
'A3'  'A'  'chamber'  'all'         30  'on'      [150 15000]  [1 1 1]  '30 deg: all three'                  'Turn back to 0 deg afterwards.'
'Z1'  ''   'zinf'     'board'        0  ''        [50 19000]   []       'Impedance: board input'             'Amp -> series R -> board input, midrange and tweeter both ON (connected).'
'Z2'  ''   'zinf'     'board_mid'    0  ''        [50 19000]   []       'Impedance: board, mid branch'       'Switch the TWEETER OFF on the switchboard (or lift its lead if the board is wired straight).'
'Z3'  ''   'zinf'     'board_tw'     0  ''        [50 19000]   []       'Impedance: board, tweeter branch'   'Tweeter back ON, switch the MIDRANGE OFF on the switchboard (or lift its lead if the board is wired straight).'
'Z4'  ''   'zinf'     'woofer'       0  ''        [5 200]      []       'Impedance: woofer in the box'       'Series R -> woofer. One vent open at the vent length in the settings, the other plugged.'
'N1'  ''   'zinf'     'nf_cone'      0  ''        [10 200]     []       'Near field: cone'                   'Series R SHORTED. Mic ~1 cm from the dust cap. Nexus on, 1 V/Pa.'
'N2'  ''   'zinf'     'nf_vent'      0  ''        [10 200]     []       'Near field: vent'                   'Series R SHORTED. Mic at the vent mouth.'
};
P = cell2struct(c, {'id','grp','station','model','angle','dsp','band','sw','title','setup'}, 2);
end
