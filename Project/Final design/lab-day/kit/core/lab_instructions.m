function I = lab_instructions(st, S)
% LAB_INSTRUCTIONS  What to set up for a run, in plain words (used by lab and labgui).
%   I.when{k}   'NOW' | 'During beeps 1' | 'During beeps 2'
%   I.what{k}   the setup text of step k, with the session's numbers filled in
%   I.head{k}   '[P1] Placement: woofer'
%   I.facts     one line: MiniDSP state, gains, angle (chamber) or series R, Nexus, vent (Zi)
%   I.lines     all of it as text lines (console / dialog box)

n = numel(st);
I = struct('when', {cell(1, n)}, 'what', {cell(1, n)}, 'head', {cell(1, n)}, 'facts', '', 'lines', {{}});
for k = 1:n
    if k == 1, I.when{k} = 'NOW'; else, I.when{k} = sprintf('During beeps %d', k-1); end
    t = st(k).setup;
    t = strrep(t, 'Out 1 gain as in lab_setup', sprintf('Out 1 gain %g dB', S.out1_gain));
    t = strrep(t, 'lab_setup().vent_mm', sprintf('%g mm', S.vent_mm));
    I.what{k} = t;
    I.head{k} = sprintf('[%s] %s', st(k).id, st(k).title);
    I.lines{end+1} = sprintf('%s  %s: %s', I.when{k}, I.head{k}, t);
end
if strcmp(st(1).station, 'chamber')
    I.facts = sprintf('MiniDSP %s.  Out 1 %g dB, Out 2 %g dB.  Angle %d deg.  Amplifier %s (do not touch).', ...
        upper(st(1).dsp), S.out1_gain, S.out2_gain, st(1).angle, S.amp_volume);
    I.lines{end+1} = sprintf('MiniDSP %s. Out 1 %g dB, Out 2 %g dB. Angle %d deg.', ...
        upper(st(1).dsp), S.out1_gain, S.out2_gain, st(1).angle);
elseif startsWith(st(1).model, 'nf')
    I.facts = sprintf('Zi/Nfield station.  Series R SHORTED.  Nexus %g V/Pa.  Vent %g mm.', S.NexusVperPa, S.vent_mm);
    I.lines{end+1} = I.facts;
else
    if isnan(S.R_series), r = 'NOT SET: type the multimeter value in Settings'; else, r = sprintf('%g ohm', S.R_series); end
    I.facts = sprintf('Zi/Nfield station.  Series R in the path: %s.  Vent %g mm.', r, S.vent_mm);
    I.lines{end+1} = I.facts;
end
end
