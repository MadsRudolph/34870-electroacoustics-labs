function A = lab_advice(m, status)
% LAB_ADVICE  What to do next after a run, in plain words.
%   m       a judged run (lab_judge): uses m.R, m.verdict, m.setup
%   status  from lab_runs (which steps are done), optional
%   A.verdict  'OK' | 'CHECK' | 'BAD'
%   A.lines    one line per thing that is not OK, each with its fix; then what comes next

if nargin < 2, status = struct(); end
P = lab_plan();
A = struct('verdict', m.verdict, 'lines', {{}});
S = m.setup;
if ~isempty(m.err)
    A.lines{end+1} = sprintf('This run could not be judged (%s). The data are saved; look at the curves.', m.err);
end
redo = sprintf('redo %s', strjoin(m.ids, ' + '));
for r = m.R
    if strcmp(r.verdict, 'OK'), continue; end
    s = P(strcmp({P.id}, r.id));
    switch r.id
    case 'bal'
        if r.offset > 0, w = 'louder'; else, w = 'quieter'; end
        new = S.out1_gain - r.offset;
        A.lines{end+1} = sprintf(['Woofer is %.1f dB %s than mid+tweeter (want within 1 dB). Change Out 1 gain by %+.1f dB: ' ...
            'set it to %.1f dB in the MiniDSP app (it was %g), type %.1f into Settings, then %s.'], ...
            abs(r.offset), w, -r.offset, new, S.out1_gain, new, redo);
    case 'sum'
        A.lines{end+1} = sprintf(['Woofer + mid/tweeter does not add up to "all" (worst %.1f dB): something changed between the ' ...
            'states (a unit not switched back ON in time on the switchboard, the box or the mic moved). Then %s.'], r.offset, redo);
    case 'F1n'
        A.lines{end+1} = sprintf(['Woofer inverted: the notch is %.1f dB at %.0f Hz (want deeper than -10 dB near 329 Hz). ' ...
            'Was Out 1 INVERT ticked during beeps 1? If not, %s. If it was, woofer and midrange are not in phase at the crossover: note it.'], ...
            r.offset, r.x, redo);
    case 'F2n'
        A.lines{end+1} = sprintf(['Tweeter swapped: the notch is %.1f dB at %.0f Hz (want deeper than -10 dB near 3.9 kHz). ' ...
            'Were the tweeter + and - swapped during beeps 2? If not, %s. If they were, midrange and tweeter are not in phase: note it.'], ...
            r.offset, r.x, redo);
    otherwise
        if isempty(s), continue; end
        if strcmp(s.station, 'chamber')
            if startsWith(s.id, 'P')
                A.lines{end+1} = sprintf(['%s (%s) is %.1f dB rms off the Lab E shape: the placement differs from Lab E. ' ...
                    'Move the box/mic back (mic 2.44 m from the front, 1.15 m high, on axis), check the MiniDSP is BYPASSED ' ...
                    'and the switchboard is set as shown, then redo P.'], s.id, s.title, r.shape);
            elseif r.shape > 6
                A.lines{end+1} = sprintf(['%s (%s) is %.1f dB rms off the expected shape: this looks like the wrong state. ' ...
                    'Was the switchboard switched in time during the beeps (the right units ON / OFF)? Then %s.'], s.id, s.title, r.shape, redo);
            else
                A.lines{end+1} = sprintf(['%s (%s) is %.1f dB rms off the expected shape in %g-%g Hz. Check the state was right ' ...
                    '(switchboard, MiniDSP %s). If it was, this is a real difference: look at the lower plot, note it and go on.'], ...
                    s.id, s.title, r.shape, s.band, upper(s.dsp));
            end
        elseif startsWith(s.model, 'board')
            if ~isempty(r.x) && r.x(1) < 3.5
                A.lines{end+1} = sprintf(['%s: |Z| drops to %.2f ohm at %.0f Hz. Below 3.5 ohm is too low for the amplifier: ' ...
                    'check the board wiring before playing loud.'], s.id, r.x(1), r.x(2));
            else
                A.lines{end+1} = sprintf(['%s (%s): level %+.1f dB from the model, worst %.1f dB around it. Check Series R in Settings ' ...
                    '(%g ohm) is the multimeter value, and that the right units are connected (switchboard / leads). Then redo %s.'], ...
                    s.id, s.title, r.offset, r.shape, S.R_series, s.id);
            end
        elseif strcmp(s.model, 'woofer')
            if isnan(r.offset)
                A.lines{end+1} = sprintf(['%s: no Lab D measurement at a %g mm vent to compare with (Lab D has 160, 200 and 240 mm). ' ...
                    'Is the vent length in Settings right?'], s.id, S.vent_mm);
            else
                A.lines{end+1} = sprintf(['%s: the box tuning is %+.1f Hz from Lab D. Check the vent length (Settings says %g mm), ' ...
                    'that the other vent is plugged and the filling is in. Then redo %s.'], s.id, r.offset, S.vent_mm, s.id);
            end
        else
            if isnan(r.offset)
                A.lines{end+1} = sprintf(['%s: no Lab D near field at a %g mm vent to compare with (Lab D has 160, 200 and 240 mm). ' ...
                    'Is the vent length in Settings right?'], s.id, S.vent_mm);
            else
                A.lines{end+1} = sprintf(['%s (%s): the shape differs from Lab D. Check the mic position (about 1 cm from the dust cap / ' ...
                    'at the vent mouth), the series R is SHORTED, the vent is %g mm. Then redo %s.'], s.id, s.title, S.vent_mm, s.id);
            end
        end
    end
end
if isempty(A.lines), A.lines{1} = 'All checks OK.'; end
if any(ismember(m.ids, {'F1', 'F2'}))
    A.lines{end+1} = 'Before the next run: swap the tweeter + and - BACK and UNtick Out 1 invert.';
end

% ---- what comes next (the order of the plan of the day)
order = {'P', 'S', 'S4', 'S5', 'F', 'A', 'Z1', 'Z2', 'Z3', 'Z4', 'N1', 'N2'};
done = fieldnames(status)';
if strcmp(A.verdict, 'OK') || isempty(A.verdict)
    for i = 1:numel(order)
        [st, ids] = lab_steps(order{i});
        if ~strcmp(st(1).station, m.station) || all(ismember(ids, done)), continue; end
        extra = '';
        if strcmp(order{i}, 'S') && any(startsWith(m.ids, 'P'))
            extra = ' Set the MiniDSP ON first (and make the board change planned for today, e.g. Rp 3.3 -> 8.2 ohm).';
        end
        A.lines{end+1} = sprintf('Next: %s (%s).%s', order{i}, strjoin({st.title}, ' / '), extra);
        return
    end
    A.lines{end+1} = 'Every planned step at this station is done. Export the figures and copy the data to the USB stick.';
end
end
