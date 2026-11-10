function I = lab_instructions(st, S, Nav)
% LAB_INSTRUCTIONS  What to do for a run, as text, plus its timeline.
%
%   I.lines    cellstr: NOW ..., During beeps 1 ..., the MiniDSP/station settings
%   I.chain    one line: MiniDSP + gains + angle (chamber) or series R + vent (Zi)
%   I.phases   struct array: name ('measure' | 'beeps'), k (state number), t0, t1 (s),
%              text (what is happening / what to switch NOW)
%   I.secs     expected duration of the whole run (s)
%   I.timeline one line with the clock of the run: 0:00 state 1 | 1:05 BEEPS ...
%
%   Durations follow the course routines: chamber = (Nav+1) periods of 1 s per state,
%   ~30.2 s of beeps between states (Beeps.wav); Zi/Nfield = (Nav+1) periods of 8 s.

if nargin < 3 || isempty(Nav), Nav = 64; end
chamber = strcmp(st(1).station, 'chamber');
n = numel(st);
I.lines = {};
for k = 1:n
    if k == 1, pre = 'NOW'; else, pre = sprintf('During beeps %d', k-1); end
    I.lines{end+1} = sprintf('%s:  [%s] %s.  %s', pre, st(k).id, st(k).title, st(k).setup);
end
if chamber
    if strcmp(st(1).dsp, 'bypass')
        I.chain = sprintf('MiniDSP BYPASSED (the Out gains do not apply). Angle %d deg. Vents plugged.', st(1).angle);
    else
        I.chain = sprintf('MiniDSP ON: Out 1 (woofer) %g dB, Out 2 (mid+tw) %g dB, invert off unless the step says so. Angle %d deg. Vents plugged.', ...
            S.out1_gain, S.out2_gain, st(1).angle);
    end
else
    if startsWith(st(1).model, 'nf')
        I.chain = sprintf('Zi/Nfield station (NI card). Series R SHORTED. Nexus %g V/Pa. One vent open at %g mm.', S.NexusVperPa, S.vent_mm);
    else
        I.chain = sprintf('Zi/Nfield station (NI card). Series R = %g ohm (multimeter). One vent open at %g mm.', S.R_series, S.vent_mm);
    end
end
I.lines{end+1} = I.chain;

% ---- timeline
I.phases = struct('name', {}, 'k', {}, 't0', {}, 't1', {}, 'text', {});
t = 0;
if chamber
    Tst = Nav + 1; Tbp = 30.2;
else
    nf = startsWith(st(1).model, 'nf');
    if nf, NavZ = 4; else, NavZ = 1; end
    Tst = 8*(NavZ + 1); Tbp = 0;
end
tl = {};
for k = 1:n
    I.phases(end+1) = struct('name', 'measure', 'k', k, 't0', t, 't1', t + Tst, ...
        'text', sprintf('Measuring state %d of %d: [%s] %s. Do not touch anything.', k, n, st(k).id, st(k).title));
    tl{end+1} = sprintf('%s state %d (%s)', mmss(t), k, st(k).id); %#ok<AGROW>
    t = t + Tst;
    if k < n
        I.phases(end+1) = struct('name', 'beeps', 'k', k, 't0', t, 't1', t + Tbp, ...
            'text', sprintf('BEEPS %d - SWITCH NOW to [%s]: %s', k, st(k+1).id, st(k+1).setup));
        tl{end+1} = sprintf('%s BEEPS: switch to %s', mmss(t), st(k+1).id); %#ok<AGROW>
        t = t + Tbp;
    end
end
I.secs = t + 3;                      % + start-up of the routine
tl{end+1} = sprintf('%s done', mmss(I.secs));
I.timeline = strjoin(tl, '  |  ');
end

function s = mmss(t)
t = round(t);
s = sprintf('%d:%02d', floor(t/60), mod(t, 60));
end
