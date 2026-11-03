function ts = ts_from_Z(fn, Z, RE, fmax)
% TS_FROM_Z  Resonance and Q values from an impedance curve (brief, Appendix B).
%
%   ts = ts_from_Z(fn, Z, RE)          free air, baffle or closed box
%   ts = ts_from_Z(fn, Z, RE, fmax)    only search below fmax (default 500 Hz)
%
%   Zmax at the peak, rc = Zmax/RE, f1 < f0 < f2 where |Z| = sqrt(RE Zmax),
%     QM = f0 sqrt(rc)/(f2 - f1),  QE = QM/(rc - 1),  QT = QM/rc
%   f1 and f2 are interpolated on a log-frequency axis. Does NOT work on a
%   vented box (two peaks).

if nargin < 4, fmax = 500; end
fn = fn(:); Zm = abs(Z(:));
k = fn > 0 & fn < fmax;
fn = fn(k); Zm = Zm(k);

[Zmax, i0] = max(Zm);
% refine the peak with a parabola through three points in log f
if i0 > 1 && i0 < numel(fn)
    x = log(fn(i0-1:i0+1)); y = Zm(i0-1:i0+1);
    c = polyfit(x, y, 2);
    f0 = exp(-c(2)/(2*c(1)));
    Zmax = polyval(c, log(f0));
else
    f0 = fn(i0);
end

rc = Zmax / RE;
Zr = sqrt(RE * Zmax);

lo = find(Zm(1:i0) < Zr, 1, 'last');
hi = i0 - 1 + find(Zm(i0:end) < Zr, 1, 'first');
if isempty(lo) || isempty(hi)
    error('|Z| never drops below sqrt(RE*Zmax) on one side: widen the band.');
end
f1 = exp(interp1(Zm([lo lo+1]), log(fn([lo lo+1])), Zr));
f2 = exp(interp1(Zm([hi-1 hi]), log(fn([hi-1 hi])), Zr));

ts.f0 = f0; ts.Zmax = Zmax; ts.RE = RE; ts.rc = rc; ts.Zr = Zr;
ts.f1 = f1; ts.f2 = f2;
ts.QM = f0 * sqrt(rc) / (f2 - f1);
ts.QE = ts.QM / (rc - 1);
ts.QT = ts.QM / rc;
end
