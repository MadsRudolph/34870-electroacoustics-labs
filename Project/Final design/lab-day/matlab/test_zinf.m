function test_zinf()
% TEST_ZINF  Check measure_zinf + compare_zinf without the NI card.
%   A stand-in for meas_mag_spec2_LabD "measures" a known load through the
%   32.9 ohm divider: the model board impedance (with AI0 on a 9.4 V DC
%   offset reading half the amplifier voltage, as in Lab D), the Lab D
%   woofer at L = 160 mm and the Lab D near field. Checks that Z / H come
%   back, k is detected, the comparisons read ~0 dB, R is required, and
%   nothing is overwritten. Must print PASS.

here = fileparts(mfilename('fullpath'));
labD = fullfile(here, '..', '..', '..', '..', 'Lab D', 'data');
set(groot, 'DefaultFigureVisible', 'off');
tmp = tempname; mkdir(tmp); dd = fullfile(tmp, 'data');
fid = fopen(fullfile(tmp, 'meas_mag_spec2_LabD.m'), 'w');
fprintf(fid, '%s\n', ...
 'function [fn,specn,f,spec,ch]=meas_mag_spec2_LabD(f1,f2,n_oct,fres,Nav)', ...
 'S = load(fullfile(fileparts(mfilename(''fullpath'')), ''stub.mat''));', ...
 'fn = S.fn(:); Va = 0.2*exp(1j*2*pi*rand(size(fn)));', ...
 'if S.nf, V1 = Va.*S.X; else, V1 = Va.*S.X./(S.R + S.X); end', ...
 'specn = [Va/S.k, V1]; f = (0:9)''; spec = zeros(10,2);', ...
 'ch = [S.dc + 0.3*sin((1:4800)''/50), 0.1*sin((1:4800)''/50)];', ...
 'assert(n_oct == 48 && fres == 0.125, ''wrong settings'');', ...
 'end');
fclose(fid);
addpath(tmp);
ok = true;

% 1. board, AI0 half voltage on a DC offset
csvf = fullfile(here, '..', 'model', 'expected_zi.csv');
assert(exist(csvf, 'file') == 2, 'run python3 model_curves.py first');
T = readmatrix(csvf, 'NumHeaderLines', 1);
stub(tmp, T(:,1), T(:,6) + 1j*T(:,7), false, 32.9, 2, 9.4);
m = measure_zinf('board', 'board', 'R', 32.9, 'datadir', dd);
r = compare_zinf(m, 'plot', false);
ok = report(m.k_amp == 2, 'AI0 DC offset detected -> V_amp = 2*AI0') && ok;
ok = report(abs(r.median_dB) < 0.01 && r.worst_dB < 0.05, 'board impedance = model (Zboth)') && ok;
ok = report(abs(r.Zmin - 4.40) < 0.05, sprintf('|Z| min %.2f ohm at %.0f Hz', r.Zmin, r.f_Zmin)) && ok;
s = load(fullfile(dd, 'zinf_board.mat'));
ok = report(all(isfield(s, {'specn', 'ch', 'dims', 'time', 'R'})), 'raw spectra, time signals, dims saved') && ok;
measure_zinf('board', 'board', 'R', 32.9, 'datadir', dd, 'plot', false);
ok = report(exist(fullfile(dd, 'zinf_board_2.mat'), 'file') == 2, 'repeat tag saved as _2') && ok;

% 2. mid branch alone, no DC offset
stub(tmp, T(:,1), T(:,2) + 1j*T(:,3), false, 32.9, 1, 0);
m = measure_zinf('board_mid', 'board', 'R', 32.9, 'datadir', dd, 'plot', false);
r = compare_zinf(m, 'plot', false);
ok = report(m.k_amp == 1 && strcmp(r.model, 'Zmid') && abs(r.median_dB) < 0.01, 'mid branch: k = 1, compared with Zmid') && ok;

% 3. woofer in the box against Lab D
W = load(fullfile(labD, 'labD_vent_L160.mat'));
stub(tmp, W.fn, W.Z, false, 32.9, 2, 9.4);
m = measure_zinf('woofer_L160', 'woofer', 'R', 32.9, 'datadir', dd, 'plot', false);
r = compare_zinf(m, 'plot', false);
ok = report(abs(r.fb - r.fb_ref) < 0.01, sprintf('woofer fb %.1f Hz = Lab D', r.fb)) && ok;

% 4. near field
N = load(fullfile(labD, 'labD_nf_cone_L160.mat'));
stub(tmp, N.fn, N.H, true, NaN, 2, 9.4);
m = measure_zinf('nf_cone_L160', 'nearfield', 'datadir', dd, 'plot', false);
r = compare_zinf(m, 'plot', false);
ok = report(abs(r.median_dB) < 0.01, 'near field (cone) = Lab D') && ok;

% 5. R is required for impedance
try
    measure_zinf('noR', 'board', 'datadir', dd);
    ok = report(false, 'missing R refused') && ok;
catch
    ok = report(true, 'missing / implausible R refused') && ok;
end

close all
rmpath(tmp); rmdir(tmp, 's');
if ok, fprintf('\nPASS\n'); else, error('test_zinf FAILED'); end
end

function stub(tmp, fn, X, nf, R, k, dc) %#ok<INUSD>
save(fullfile(tmp, 'stub.mat'), 'fn', 'X', 'nf', 'R', 'k', 'dc');
end

function ok = report(c, msg)
if c, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
ok = c;
end
