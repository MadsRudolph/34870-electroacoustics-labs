function fix = lab_errfix(err)
% LAB_ERRFIX  A failed measurement in plain words: what to do about it.
%   fix = lab_errfix(err)    err = MException (or a message string)

if ischar(err) || isstring(err), msg = char(err); id = ''; else, msg = err.message; id = err.identifier; end
t = lower([id ' ' msg]);
if contains(t, 'cancel')
    fix = 'Cancelled. Nothing was saved.';
elseif contains(t, 'beeps')
    fix = ['The course routine cannot find beeps.wav. Fix: copy Beeps.wav from "Lab E/matlab/course" into the ' ...
        'current MATLAB folder (or cd into the folder that holds meas_mag_spec2_SoundCard_LabE), then press Measure again.'];
elseif contains(t, 'no correction available') || contains(t, 'umiksn')
    fix = 'The UMIK serial number is not one the course has a calibration for. Type the number on the mic label (708-0329, 708-0332 or 708-0335) in Settings.';
elseif contains(t, 'umik') || contains(t, 'audiorecorder') || contains(t, 'audioplayer') || ...
        contains(t, 'deviceid') || contains(t, 'device id') || contains(t, 'audiodevinfo')
    fix = ['The UMIK or the sound card was not found. Fix: plug the UMIK into USB, then RESTART MATLAB ' ...
        '(it only looks for audio devices when it starts) and open labgui again. Check that Windows sees ' ...
        '"Umik", "Line In" and "Speakers".'];
elseif contains(t, 'r_series') || contains(t, 'series resistor')
    fix = 'Enter the series resistor in Settings first: the MULTIMETER value (about 32.9 ohm), not R_E.';
elseif contains(t, 'daq') || contains(t, 'dev4') || contains(t, 'ni-') || contains(t, 'data acquisition')
    fix = ['The NI card (Dev4) was not found. Fix: check its USB cable and power, close NI MAX and any other ' ...
        'MATLAB, and ask the TA which device name this PC uses (the course routine expects Dev4).'];
elseif contains(t, 'meas_mag_spec2') || contains(t, 'createmultitone')
    fix = ['A course routine was not found. The labs folder must be copied whole: "Lab D" and "Lab E" next to ' ...
        '"Project". Or add the lab PC''s own course folder to the path.'];
elseif contains(t, 'out of memory')
    fix = 'MATLAB ran out of memory: close the course routine''s figures (close all) and try again.';
else
    fix = ['Unexpected error: nothing was saved. Read the message above, fix the cause and press Measure again. ' ...
        'Fallback: the Tuesday scripts in lab-day/manual (project_run.m / zinf_run.m) do the same measurement.'];
end
end
