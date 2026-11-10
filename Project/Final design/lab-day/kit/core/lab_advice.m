function [verdict, lines, next] = lab_advice(m, runs)
% LAB_ADVICE  One verdict for a run and, in plain words, what to do next.
%
%   [verdict, lines, next] = lab_advice(m, runs)
%   m      a run with its checks (m.R, see lab_runs / lab_check)
%   runs   every run of the day (for comparisons across runs, e.g. S4 vs S5); optional
%   verdict  'OK' | 'CHECK' | 'BAD': the worst of the step checks and the signal flags
%   lines    cellstr: each check's result, then 'DO:' lines for everything not OK
%   next     the next step of the plan that is not OK yet ('' when all are)

if nargin < 2, runs = {}; end
if isempty(m)                        % lab_advice([], runs): only the next step of the plan
    verdict = ''; lines = {}; next = next_step(runs); return
end
R = m.R;
[flags, flev] = lab_flags(m);
verdict = flev;
for i = 1:numel(R), verdict = worst(verdict, R(i).verdict); end

lines = {};
for i = 1:numel(R)
    lines{end+1} = sprintf('%-5s %-6s %s', R(i).id, R(i).verdict, R(i).msg); %#ok<AGROW>
end
for i = 1:numel(flags), lines{end+1} = ['SIGNAL ' flags{i}]; end %#ok<AGROW>

% ---- what to do, for everything that is not OK
do = {};
S = m.setup;
for i = 1:numel(R)
    r = R(i);
    if strcmp(r.verdict, 'OK'), continue; end
    switch r.id
    case {'P1', 'P2', 'P3'}
        do{end+1} = sprintf(['%s: the placement differs from Lab E. Check the box position on the platform, mic ' ...
            'distance 2.44 m and height 1.15 m, angle 0 deg, the MiniDSP really bypassed; then redo P.'], r.id); %#ok<AGROW>
        if any(strcmp(r.id, {'P2', 'P3'}))
            do{end+1} = sprintf(['If P1 is OK but %s is not: measure %sd (unit wired straight to the amplifier). ' ...
                'OK there = the board is the problem; not OK there = the unit itself changed.'], r.id, r.id); %#ok<AGROW>
        end
    case {'P2d', 'P3d'}
        do{end+1} = sprintf('%s: the unit itself differs from Lab E (or the placement). Compare with P1: if P1 is OK, the unit changed.', r.id); %#ok<AGROW>
    case {'S1', 'S2', 'S3', 'S4', 'S5', 'A1', 'A2', 'A3', 'F0'}
        do{end+1} = sprintf(['%s: the shape differs from the expectation. Check the MiniDSP (filters pasted, PEQ/Comp/FIR ' ...
            'bypassed, 96 kHz, invert off), the cables, the board wiring; then compare with the placement run P.'], r.id); %#ok<AGROW>
    case {'F1', 'F2'}
        do{end+1} = sprintf('%s: looks different from the model: was the switch made during the beeps?', r.id); %#ok<AGROW>
    case 'bal'
        new = S.out1_gain - r.offset;
        do{end+1} = sprintf(['Balance: change the MiniDSP Out 1 gain by %+.1f dB (from %g to %.1f dB), type the new ' ...
            'value in Settings, then measure S again.'], -r.offset, S.out1_gain, new); %#ok<AGROW>
    case 'sum'
        do{end+1} = ['Sum check: woofer + mid/tw does not add up to "all". Something moved between the states or a ' ...
            'switch came late: measure the run again and switch only during the beeps.']; %#ok<AGROW>
    case 'F1n'
        do{end+1} = ['Woofer flip: the notch is shallow or in the wrong place. Was Out 1 INVERT ticked during beeps 1? ' ...
            'If yes, woofer and mid/tw are not in phase at 325 Hz: check the MiniDSP filters and the delay (0).']; %#ok<AGROW>
    case 'F2n'
        do{end+1} = ['Tweeter flip: the notch is shallow or in the wrong place. Was the tweeter swapped during beeps 2? ' ...
            'If yes, midrange and tweeter are not in phase at the crossover: check the board values and polarity.']; %#ok<AGROW>
    case {'Z1', 'Z2', 'Z3'}
        if ~isempty(r.x) && r.x(1) < 3.5
            do{end+1} = sprintf('%s: |Z| goes below 3.5 ohm: a short or a wrong part on the board. Check the wiring.', r.id); %#ok<AGROW>
        else
            do{end+1} = sprintf(['%s: level or shape off: check R_series in Settings (multimeter value), the leads, ' ...
                'and which drivers are connected for this step.'], r.id); %#ok<AGROW>
        end
    case 'Z4'
        do{end+1} = sprintf(['Z4: the vent tuning differs from Lab D at %g mm: is ONE vent open at %g mm and the other ' ...
            'plugged, the filling in? Is vent_mm in Settings right?'], S.vent_mm, S.vent_mm); %#ok<AGROW>
    case {'N1', 'N2'}
        do{end+1} = sprintf(['%s: differs from Lab D: mic distance (~1 cm), Nexus setting (%g V/Pa in Settings), ' ...
            'series R shorted, vent length %g mm?'], r.id, S.NexusVperPa, S.vent_mm); %#ok<AGROW>
    end
end
if ~isempty(flags), do{end+1} = 'See the SIGNAL lines above.'; end

% ---- across runs: midrange vs tweeter level (S4 / S5, the L-pad question of 10-Nov)
if any(ismember(m.ids, {'S4', 'S5'})) && ~isempty(runs)
    o4 = lastoffset(runs, 'S4'); o5 = lastoffset(runs, 'S5');
    if ~isnan(o4) && ~isnan(o5)
        lines{end+1} = sprintf(['INFO  tweeter vs midrange %+.1f dB against the model (0 = as designed; ' ...
            '10-Nov with Rp 3.3 ohm: about -4 dB).'], o5 - o4);
    end
end

if isempty(do)
    lines{end+1} = 'Everything in this run is OK.';
else
    lines = [lines, {''}, strcat({'DO: '}, do)];
end
next = next_step(runs);
if ~isempty(next), lines{end+1} = sprintf('Next in the plan: %s', next); end
end

function o = lastoffset(runs, id)
o = NaN;
for i = numel(runs):-1:1
    r = runs{i}.R(strcmp({runs{i}.R.id}, id));
    if ~isempty(r), o = r.offset; return; end
end
end

function s = next_step(runs)
% the Thursday order: first entry whose steps are not all OK
order = {'P', 'S', 'S4', 'S5', 'F', 'A', 'Z1', 'Z2', 'Z3', 'Z4', 'N1', 'N2'};
P = lab_plan();
v = containers.Map();
for i = 1:numel(runs)
    for r = runs{i}.R, v(r.id) = r.verdict; end
end
s = '';
for i = 1:numel(order)
    ids = {P(strcmp({P.grp}, order{i})).id};
    if isempty(ids), ids = order(i); end
    if ~all(cellfun(@(x) isKey(v, x) && strcmp(v(x), 'OK'), ids))
        s = order{i}; return
    end
end
end

function v = worst(a, b)
o = {'OK', 'CHECK', 'BAD'};
v = o{max(find(strcmp(o, a)), find(strcmp(o, b)))};
end
