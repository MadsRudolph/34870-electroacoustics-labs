function r = analyse_labD(d, datadir)
% ANALYSE_LABD  T-S parameters, Vas, vent tuning and room modes from Lab D.
%
%   r = analyse_labD                 uses labD_dims() and ../data
%   r = analyse_labD(d, datadir)     (the test passes synthetic data this way)
%
%   Expects data/labD_woofer_free.mat and data/labD_woofer_closed.mat from
%   measure_labD, plus whatever vent and near-field tags labD_dims lists.
%   Prints a summary; run it in the lab right after the closed-box
%   measurement so a bad curve can be repeated before you leave.

here = fileparts(mfilename('fullpath'));
if nargin < 1, d = labD_dims(); end
if nargin < 2, datadir = fullfile(here, '..', 'data'); end
ld = @(tag) load(fullfile(datadir, ['labD_' tag '.mat']));

T = d.T_celsius; if isnan(T), T = 20; end
c = 331.3 * sqrt(1 + T/273.15);
rho = 1.2041 * 293.15 / (273.15 + T);
r.c = c; r.rho = rho;

% --- free air and closed box -------------------------------------------
free = ld('woofer_free');
r.free = ts_from_Z(free.fn, free.Z, d.RE_woofer);
fprintf('\nFree air:   fs = %6.2f Hz  Zmax = %5.1f ohm  rc = %5.2f  Qms = %5.2f  Qes = %5.3f  Qts = %5.3f\n', ...
    r.free.f0, r.free.Zmax, r.free.rc, r.free.QM, r.free.QE, r.free.QT);
fprintf('            f1 = %.2f Hz, f2 = %.2f Hz, sqrt(f1 f2) = %.2f Hz\n', ...
    r.free.f1, r.free.f2, sqrt(r.free.f1*r.free.f2));

closed = ld('woofer_closed');
r.closed = ts_from_Z(closed.fn, closed.Z, d.RE_woofer);
fprintf('Closed box: fc = %6.2f Hz  Zmax = %5.1f ohm  rc = %5.2f  Qmc = %5.2f  Qec = %5.3f  Qtc = %5.3f\n', ...
    r.closed.f0, r.closed.Zmax, r.closed.rc, r.closed.QM, r.closed.QE, r.closed.QT);

% --- Vas by the added-compliance method (Lecture 8 section 6) -----------
r.VB = prod(d.box_inner);
r.alpha = (r.closed.f0 / r.free.f0)^2 - 1;
r.Vas = r.VB * r.alpha;
fprintf('\nV_B = %.2f L, alpha = (fc/fs)^2 - 1 = %.3f, V_AS = %.2f L\n', ...
    1e3*r.VB, r.alpha, 1e3*r.Vas);
fprintf('Check: fc/fs = %.3f should equal Qtc/Qts = %.3f (both = sqrt(1+alpha))\n', ...
    r.closed.f0/r.free.f0, r.closed.QT/r.free.QT);

% --- the rest of the parameters, if the cone was measured ---------------
if ~isnan(d.cone_diam)
    SD = pi * (d.cone_diam/2)^2;
    ws = 2*pi*r.free.f0;
    CAS = r.Vas / (rho*c^2);
    CMS = CAS / SD^2;
    MMS = 1 / (ws^2 * CMS);
    r.mech = struct('SD', SD, 'CMS', CMS, 'MMS', MMS, ...
        'Bl', sqrt(ws * d.RE_woofer * MMS / r.free.QE), ...
        'RMS', ws * MMS / r.free.QM);
    fprintf('S_D = %.1f cm^2, C_MS = %.3g m/N, M_MS = %.2f g, Bl = %.2f Tm, R_MS = %.2f kg/s\n', ...
        1e4*SD, CMS, 1e3*MMS, r.mech.Bl, r.mech.RMS);
end

% --- vents: measured fb against the Helmholtz formula --------------------
% M_AP = rho (L + 1.46 a) / S_P per tube (one flanged + one unflanged end);
% N equal tubes in parallel divide it by N.  C_AB = V_B / (rho c^2).
aP = d.vent_radius; SP = pi*aP^2;
r.vents = [];
for k = 1:size(d.vents, 1)
    [tag, L, N] = d.vents{k, :};
    z = ld(tag);
    v = fb_from_Z(z.fn, z.Z);
    v.tag = tag; v.L = L; v.N = N;
    v.fb_calc = c/(2*pi) * sqrt(N*SP / (r.VB * (L + 1.46*aP)));
    r.vents = [r.vents v]; %#ok<AGROW>
    fprintf('%-12s L = %5.1f mm, %d open: peaks %.1f / %.1f Hz, |Z| min (fb) = %.1f Hz, phase 0 = %.1f Hz, calc = %.1f Hz\n', ...
        tag, 1e3*L, N, v.fL, v.fH, v.fb, v.fb_phase, v.fb_calc);
end

% --- near field: notch on the cone, peak at the vent ---------------------
r.nf = [];
for k = 1:size(d.nearfield, 1)
    [ct, vt, L] = d.nearfield{k, :};
    cn = ld(ct); vn = ld(vt);
    sel = cn.fn > 5 & cn.fn < 300;
    f = cn.fn(sel);
    [~, i] = min(abs(cn.H(sel)));
    [~, j] = max(abs(vn.H(sel)));
    n = struct('L', L, 'fb_cone_notch', f(i), 'fb_vent_peak', f(j));
    r.nf = [r.nf n]; %#ok<AGROW>
    fprintf('Near field L = %5.1f mm: cone notch %.1f Hz, vent peak %.1f Hz\n', ...
        1e3*L, n.fb_cone_notch, n.fb_vent_peak);
end

% --- room modes below 120 Hz (rigid rectangular room) --------------------
if all(~isnan(d.room))
    [nx, ny, nz] = ndgrid(0:6, 0:6, 0:6);
    fm = c/2 * sqrt((nx/d.room(1)).^2 + (ny/d.room(2)).^2 + (nz/d.room(3)).^2);
    fm = unique(round(fm(fm > 0 & fm < 120)));
    r.room_modes = fm;
    fprintf('\nRoom modes below 120 Hz: %s\n', sprintf('%.0f ', fm));
end
end
