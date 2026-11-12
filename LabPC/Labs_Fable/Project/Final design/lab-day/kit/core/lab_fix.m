function [what, fix] = lab_fix(e)
% LAB_FIX  A failed measurement in plain words: what happened and what to do about it.
%   e = the MException caught around the course routine (or any kit error).
L = labpaths;
id = e.identifier; msg = e.message; s = lower([id ' ' msg]);
if contains(s, 'audioread') || contains(s, 'beeps') || contains(s, 'filename specified was not found')
    what = 'The course routine could not find beeps.wav.';
    fix = sprintf(['In MATLAB: cd(''%s'') and start labgui again from there (type: labgui), ' ...
        'or copy Beeps.wav from that folder into %s.'], L.labEcourse, L.kit);
elseif contains(s, 'umik') || contains(s, 'audiorecorder') || contains(s, 'audioplayer') || ...
        contains(s, 'device id') || contains(s, 'deviceid') || contains(s, 'audiodev')
    what = 'The sound card or the UMIK was not found.';
    fix = ['Plug the UMIK into USB, check Windows shows it as a recording device, then RESTART MATLAB ' ...
        '(devices are only found at start-up) and open labgui again. Nothing was saved, nothing is lost.'];
elseif contains(s, 'no correction available')
    what = 'The UMIK serial number is not one of the three with a calibration file.';
    fix = 'Read the label on the UMIK and set "UMIK serial" in Settings to 708-0329, 708-0332 or 708-0335.';
elseif contains(s, 'lab:rseries') || contains(s, 'r_series')
    what = 'The series resistor value is missing.';
    fix = 'Measure the series resistor with the multimeter (about 32.9 ohm) and type it into Settings > Series R.';
elseif contains(s, 'daq') || contains(s, 'ni ') || contains(s, 'session') || contains(s, 'meas_mag_spec2_labd')
    what = 'The NI card (Zi/Nfield station) did not answer.';
    fix = 'Is this the Zi/Nfield PC with the NI-4431 connected and switched on? Restart MATLAB and try again; else ask the TA.';
elseif contains(s, 'meas_mag_spec2_soundcard') || contains(s, 'undefined function') || contains(s, 'unrecognized function')
    what = 'A course routine (or one of its helper files) was not found.';
    fix = sprintf('The copy of the Labs folder is incomplete. It must contain %s and %s. Copy the whole Labs folder again.', ...
        L.labEcourse, L.labDcourse);
elseif contains(s, 'lab:demo')
    what = 'Demo data and real data must stay apart.';
    fix = 'Start the GUI with labgui for real measurements and labgui(''demo'') for rehearsing.';
elseif contains(s, 'cannot share a run') || contains(s, 'same angle') || contains(s, 'at most 3') || ...
        contains(s, 'one step per run') || contains(s, 'no step chosen') || contains(s, 'twice in one run')
    what = msg;
    fix = 'Pick one step, one whole run (P, S, F, A), or up to three chamber steps with Ctrl+click.';
else
    what = 'The measurement stopped with an error.';
    fix = 'Read the message, check the cables and devices, and press Measure again. Nothing was saved, nothing is lost.';
end
end
