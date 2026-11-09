function test_project()
% TEST_PROJECT  Check measure_project + compare_project without the sound card or UMIK.
%   A stand-in for the course routine "measures" the model curves themselves
%   (../model/expected_on.csv, on its own grid), scaled by 0.5 (-6.0 dB) and with one random
%   delay per run, shaped exactly like the real routine's output. Then:
%   H recovered, offset -6.0 dB for every state, no shape error, the sum
%   check and the polarity notches as the model says, nothing overwritten,
%   design snapshot and dims saved, more than 3 states refused.

here = fileparts(mfilename('fullpath'));
set(groot, 'DefaultFigureVisible', 'off');
tmp = tempname; mkdir(tmp); dd = fullfile(tmp, 'data'); mkdir(dd);
csvf = fullfile(here, '..', 'model', 'expected_on.csv');
assert(exist(csvf, 'file') == 2, 'run python3 model_curves.py first');
fid = fopen(fullfile(tmp, 'meas_mag_spec2_SoundCard_LabE.m'), 'w');
fprintf(fid, '%s\n', ...
 'function [fn,specn,f,spec,ch]=meas_mag_spec2_SoundCard_LabE(f1,f2,n_oct,fres,Nav,UmikSN,IncAngle,Nmeas)', ...
 'S = load(fullfile(fileparts(mfilename(''fullpath'')), ''stub.mat''));', ...
 'fn = S.f(:);   % the model grid itself (complex data cannot be interpolated: 7 ms of delay)', ...
 'Np = 48000/fres; f = (0:Np-1)*fres; Nf = numel(fn);', ...
 'specn = zeros(Nf,2,Nmeas); spec = zeros(Np,2,Nmeas); ch = zeros(Np,2,Nmeas);', ...
 'tau = 1e-3*rand;', ...
 'for k = 1:Nmeas', ...
 '  Hm = S.H(:,k);', ...
 '  V = 0.05*exp(1j*2*pi*rand(Nf,1));', ...
 '  specn(:,:,k) = [V, V.*0.5.*Hm.*exp(-1j*2*pi*fn*tau)];', ...
 '  ch(:,:,k) = 0.3*[sin(2*pi*(0:Np-1)''/Np), 0.5*sin(2*pi*(0:Np-1)''/Np)];', ...
 'end', ...
 'if Nmeas == 1, specn = specn(:,:,1); spec = spec(:,:,1); ch = ch(:,:,1); end', ...
 'assert(f1 == 50 && f2 == 20000 && fres == 1 && n_oct == 48 && Nav == 64, ''wrong settings'');', ...
 'assert(ischar(UmikSN) && IncAngle == 0, ''wrong mic settings'');', ...
 'end');
fclose(fid);
addpath(tmp);
T = readmatrix(csvf, 'NumHeaderLines', 1);
fid = fopen(csvf); hdr = strsplit(strtrim(fgetl(fid)), ','); fclose(fid);
model = @(s) T(:, strcmp(hdr, [s '_re'])) + 1j*T(:, strcmp(hdr, [s '_im']));
stub = @(states) writestub(fullfile(tmp, 'stub.mat'), T(:,1), ...
    cell2mat(cellfun(model, states, 'UniformOutput', false)));

ok = true;
check = @(c, msg) report(c, msg);

st = {'woofer', 'midtw', 'all'}; stub(st);
m = measure_project('R1_split_0', 0, st, 'datadir', dd);
r = compare_project(m);
ok = check(all(abs(r.offset_dB + 20*log10(2)) < 0.05), 'offset -6.0 dB found for every state') && ok;
ok = check(all(r.shape_rms_dB < 0.1), 'no shape error left after the offset') && ok;
ok = check(abs(r.channel_gap_dB) < 0.05, 'woofer and mid+tweeter channels agree') && ok;
ok = check(r.sum_check_dB < 0.05, '|woofer + midtw| = |all| within one run') && ok;
s = load(fullfile(dd, 'project_R1_split_0.mat'));
ok = check(isfield(s, 'spec') && isfield(s, 'ch') && isfield(s, 'time') && isfield(s, 'dims'), ...
    'raw spectra, time signals, timestamp and dims saved') && ok;
ok = check(contains(s.design.minidsp_out1, 'biquad2') && contains(s.design.design_json, '"fc": 325'), ...
    'design snapshot (MiniDSP texts + design.json) saved') && ok;

measure_project('R1_split_0', 0, st, 'datadir', dd, 'plot', false);
ok = check(exist(fullfile(dd, 'project_R1_split_0_2.mat'), 'file') == 2, 'repeat tag saved as _2') && ok;

st = {'all', 'flipW', 'flipT'}; stub(st);
m = measure_project('R3_flip_0', 0, st, 'datadir', dd);
r = compare_project(m);
ok = check(abs(r.flipW_notch(1) - 329) < 15 && r.flipW_notch(2) < -15, ...
    sprintf('woofer-inverted notch at %.0f Hz, %.1f dB', r.flipW_notch)) && ok;
ok = check(abs(r.flipT_notch(1) - 3928) < 200 && r.flipT_notch(2) < -10, ...
    sprintf('tweeter-swapped notch at %.0f Hz, %.1f dB', r.flipT_notch)) && ok;

st = {'mid'}; stub(st);
m = measure_project('one_state', 0, 'mid', 'datadir', dd);
ok = check(size(m.H, 2) == 1 && abs(compare_project(m).offset_dB + 6.02) < 0.05, 'single state (Nmeas = 1) works') && ok;

try
    measure_project('too_many', 0, {'woofer', 'midtw', 'all', 'mid'}, 'datadir', dd);
    ok = check(false, 'four states refused') && ok;
catch
    ok = check(true, 'four states refused (course routine does at most 3)') && ok;
end

close all
rmpath(tmp); rmdir(tmp, 's');
if ok, fprintf('\nPASS\n'); else, error('test_project FAILED'); end
end

function writestub(file, f, H) %#ok<INUSD>
save(file, 'f', 'H');
end

function ok = report(c, msg)
if c, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
ok = c;
end
