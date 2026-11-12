% TEST_LABD  Run the Lab D analysis on synthetic data with known answers.
% No hardware needed. Builds a woofer from chosen T-S parameters, simulates
% the 33 ohm measurement exactly as meas_mag_spec2_LabD + measure_labD would
% store it (free air, closed box, three vent lengths), runs analyse_labD
% and checks that the parameters come back.

rho = 1.2041; c = 343.2;                 % 20 degC, as analyse_labD uses
RE = 6.0; LE = 0.4e-3; R = 33;
fs = 40; Qms = 4; Qes = 0.45; Vas = 25e-3; SD = pi*0.065^2;
VB = 0.25*0.35*0.23;                     % 20.1 L
aP = 0.0175; QL = 7;

ws = 2*pi*fs; CAS = Vas/(rho*c^2); CMS = CAS/SD^2; MMS = 1/(ws^2*CMS);
RMS = ws*MMS/Qms; Bl = sqrt(ws*RE*MMS/Qes); CAB = VB/(rho*c^2);

fres = 0.125; n_oct = 48;
fn = fres * unique(round(2.^(log2(1):1/n_oct:log2(10000)) / fres));
fn = fn(fn >= 1).';
w = 2*pi*fn;

zmech = @(ZAback) 1j*w*MMS + RMS + 1./(1j*w*CMS) + SD^2*ZAback;
zel = @(ZAback) RE + 1j*w*LE + Bl^2 ./ zmech(ZAback);

tmp = tempname; mkdir(tmp);

% the stored Z goes through the measurement formula, as in the lab
roundtrip = @(Z) R * (Z./(R+Z)) ./ (1 - Z./(R+Z));

store(tmp, 'woofer_free', fn, roundtrip(zel(0)));
store(tmp, 'woofer_closed', fn, roundtrip(zel(1./(1j*w*CAB))));

L = [0.05 0.10 0.15]; tags = {'vent_L1','vent_L2','vent_L3'};
for k = 1:3
    MAP = rho*(L(k) + 1.46*aP)/(pi*aP^2);
    RAL = QL/sqrt(CAB/MAP);
    Y = 1./(1j*w*MAP) + 1/RAL + 1j*w*CAB;
    store(tmp, tags{k}, fn, roundtrip(zel(1./Y)));
end

d = struct('T_celsius', 20, 'RE_woofer', RE, 'cone_diam', 0.13, ...
    'box_inner', [0.25 0.35 0.23], 'vent_radius', aP, ...
    'vents', {[tags' num2cell(L') {1;1;1}]}, 'nearfield', {cell(0,3)}, ...
    'room', [6.0 4.5 2.8]);

r = analyse_labD(d, tmp);

err = @(a, b) abs(a/b - 1);
fprintf('\n--- recovery (true value in brackets) ---\n');
fprintf('fs   %.2f (%.2f)\nQms  %.3f (%.3f)\nQes  %.3f (%.3f)\nVas  %.2f L (%.2f)\nBl   %.2f (%.2f)\n', ...
    r.free.f0, fs, r.free.QM, Qms, r.free.QE, Qes, 1e3*r.Vas, 1e3*Vas, r.mech.Bl, Bl);
ok = err(r.free.f0, fs) < 0.01 && err(r.free.QM, Qms) < 0.03 && ...
     err(r.free.QE, Qes) < 0.03 && err(r.Vas, Vas) < 0.03;
for v = r.vents
    ok = ok && err(v.fb, v.fb_calc) < 0.05;
end
if ok, disp('PASS'); else, error('test_labD failed'); end
rmdir(tmp, 's');

function store(dir, tag, fn, Z) %#ok<INUSD>
save(fullfile(dir, ['labD_' tag '.mat']), 'fn', 'Z');
end
