function M = calibrate_labC(mic, device, f, SPL, H21_at_f)
% CALIBRATE_LABC  Part 2: one single-frequency sensitivity calibration, logged to data/labC_calibration_log.csv.
%
%   calibrate_labC('4133', '42AG #1', 1000, 94.00, H_21_1000)
%   calibrate_labC('4134', 'pistonphone', 250, 124.0, H_21_250)
%
% f and SPL come from the calibration sticker / certificate of THAT device (they differ per unit).
% H21_at_f is the system response from Part 1 at that frequency (measure_labC('ref','system') prints it).
% Nexus gain is 1 with the brief's settings. Repeat each combination 2-3 times (take the microphone out
% and put it back in between): that is the repeatability the quiz asks about.
addpath(fullfile(fileparts(mfilename('fullpath')), 'course'));
M = Calibrate(f, SPL, 1) / abs(H21_at_f);
fprintf('%s with %s: M = %.3f mV/Pa  (%.2f dB re 1 V/Pa)\n', mic, device, M*1e3, 20*log10(M));
d = fullfile(fileparts(mfilename('fullpath')), '..', 'data'); if ~exist(d, 'dir'), mkdir(d); end
file = fullfile(d, 'labC_calibration_log.csv'); new = ~exist(file, 'file');
fid = fopen(file, 'a'); if new, fprintf(fid, 'time,mic,device,f_Hz,SPL_dB,H21_abs,M_V_per_Pa\n'); end
fprintf(fid, '%s,%s,%s,%g,%g,%.6f,%.6e\n', datestr(now, 31), mic, device, f, SPL, abs(H21_at_f), M); fclose(fid); %#ok<TNOW1,DATST>
end
