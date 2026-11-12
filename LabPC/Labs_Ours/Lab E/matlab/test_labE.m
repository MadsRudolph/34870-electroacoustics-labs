function test_labE()
% TEST_LABE  Check measure_labE without the sound card or the UMIK.
%   A stand-in for the course routine returns three known transfer
%   functions (gain, delay and a resonance), shaped exactly like the real
%   one: specn is Nf x 2 for one measurement and Nf x 2 x Nmeas for more.
%   Checks that H is recovered for every unit, that nothing is
%   overwritten, and that the 'baffle' and 'system' defaults are right.

here = fileparts(mfilename('fullpath'));
tmp = tempname; mkdir(tmp); mkdir(fullfile(tmp, 'data'));
fid = fopen(fullfile(tmp, 'meas_mag_spec2_SoundCard_LabE.m'), 'w');
fprintf(fid, '%s\n', ...
 'function [fn,specn,f,spec,ch]=meas_mag_spec2_SoundCard_LabE(f1,f2,n_oct,fres,Nav,UmikSN,IncAngle,Nmeas)', ...
 'fn = round(f1*2.^(0:1/n_oct:log2(f2/f1))/fres)*fres; fn = unique(fn);', ...
 'Np = 48000/fres; f = (0:Np-1)*fres; Nf = numel(fn);', ...
 'specn = zeros(Nf,2,Nmeas); spec = zeros(Np,2,Nmeas); ch = zeros(Np,2,Nmeas);', ...
 'for k = 1:Nmeas', ...
 '  V = 0.05*exp(1j*2*pi*rand(Nf,1));', ...
 '  x = fn(:)/(300*k);', ...
 '  Hk = k*exp(-1j*2*pi*fn(:)*1e-3*k) .* (1j*x)./(1 - x.^2 + 1j*x/2);', ...
 '  specn(:,:,k) = [V, V.*Hk];', ...
 '  ch(:,:,k) = 0.3*[sin(2*pi*(0:Np-1)''/Np), 0.5*sin(2*pi*(0:Np-1)''/Np)];', ...
 'end', ...
 'if Nmeas == 1, specn = specn(:,:,1); spec = spec(:,:,1); ch = ch(:,:,1); end', ...
 'assert(f1 == 50 && f2 == 20000 && fres == 1, ''wrong range'');', ...
 'assert(ischar(UmikSN) && IncAngle == 0, ''wrong mic settings'');', ...
 'end');
fclose(fid);
addpath(tmp);
dd = fullfile(tmp, 'data');

ok = true;
check = @(c, msg) report(c, msg);

% part 1: one measurement, defaults 24/oct, Nav 16
m = measure_labE('box_0', 'baffle', 0, 'datadir', dd);
x = m.fn/300; Hk = exp(-1j*2*pi*m.fn*1e-3) .* (1j*x)./(1 - x.^2 + 1j*x/2);
ok = check(max(abs(m.H - Hk)) < 1e-12, 'baffle: H recovered') && ok;
ok = check(m.n_oct == 24 && m.Nav == 16 && m.Nmeas == 1, 'baffle: brief defaults (24/oct, Nav 16, Nmeas 1)') && ok;
ok = check(isequal(size(m.peak), [2 1]), 'baffle: peak is 2 x 1') && ok;

% repeat tag must not overwrite
measure_labE('box_0', 'baffle', 0, 'datadir', dd);
ok = check(exist(fullfile(dd, 'labE_box_0_2.mat'), 'file') == 2, 'repeat tag saved as _2') && ok;

% part 2: three units in one run, defaults 48/oct, Nav 64
m = measure_labE('system_0', 'system', 0, 'datadir', dd);
err = 0;
for k = 1:3
    x = m.fn/(300*k);
    Hk = k*exp(-1j*2*pi*m.fn*1e-3*k) .* (1j*x)./(1 - x.^2 + 1j*x/2);
    err = max(err, max(abs(m.H(:,k) - Hk)));
end
ok = check(err < 1e-12, 'system: H of all three units recovered') && ok;
ok = check(m.n_oct == 48 && m.Nav == 64 && m.Nmeas == 3, 'system: brief defaults (48/oct, Nav 64, Nmeas 3)') && ok;
ok = check(isequal(m.units, {'woofer','midrange','tweeter'}), 'system: unit order stored') && ok;
s = load(fullfile(dd, 'labE_system_0.mat'));
ok = check(isfield(s, 'spec') && isfield(s, 'ch') && isfield(s, 'time'), 'raw spectra, time signals and timestamp saved') && ok;

close all
rmpath(tmp); rmdir(tmp, 's');
if ok, fprintf('\nPASS\n'); else, error('test_labE FAILED'); end
end

function ok = report(c, msg)
if c, fprintf('  ok    %s\n', msg); else, fprintf('  FAIL  %s\n', msg); end
ok = c;
end
