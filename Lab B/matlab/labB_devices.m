function labB_devices()
% LABB_DEVICES  Show which audio devices the course routine will pick on this PC.
%
% Run this FIRST on the lab PC (after the UMIK is plugged in and MATLAB restarted).
% The course routine picks the devices by name: an input containing 'Umik', an input
% containing 'Line In' and an output containing 'Speakers' (version of 21-Sep-2026;
% the earlier version wanted 'Line'+'USB' and 'Speakers'+'USB'). If one of the three
% comes out as NaN below, audiorecorder/audioplayer will fail: ask Vicente or Teguh,
% or edit the contains(...) tests in matlab/course/meas_mag_spec2_SoundCard_LabB.m
% (lines 88-98) to match a name printed here.
info = audiodevinfo;
umik = NaN; linein = NaN; spk = NaN;
fprintf('\nINPUT devices\n');
for k = 1:numel(info.input)
    n = info.input(k).Name; id = info.input(k).ID; tag = '';
    if contains(n, 'Umik'),    umik   = id; tag = '  <-- UMIK (microphone channel, specn(:,2))'; end
    if contains(n, 'Line In'), linein = id; tag = '  <-- Line In (loudspeaker signal, specn(:,1))'; end
    fprintf('  ID %3d  %s%s\n', id, n, tag);
end
fprintf('\nOUTPUT devices\n');
for k = 1:numel(info.output)
    n = info.output(k).Name; id = info.output(k).ID; tag = '';
    if contains(n, 'Speakers'), spk = id; tag = '  <-- Speakers (multitone out)'; end
    fprintf('  ID %3d  %s%s\n', id, n, tag);
end
fprintf('\nRoutine will use:  Umik = %g,  Line In = %g,  Speakers = %g\n', umik, linein, spk);
if any(isnan([umik linein spk]))
    warning('A device was not found by name. Do not start measuring until all three are set.');
else
    fprintf('All three found. Go ahead: measure_labB(''nomockup'', ''708-03xx'')\n\n');
end
end
