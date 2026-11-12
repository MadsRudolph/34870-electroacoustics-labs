function v = fb_from_Z(fn, Z, fmax)
% FB_FROM_Z  Vent tuning from a vented-box impedance curve.
%
%   v = fb_from_Z(fn, Z)        search below fmax = 300 Hz
%
%   A vented box gives two impedance peaks, fL < fH, with a minimum between
%   them. The minimum sits at (very nearly) the vent resonance fb: there the
%   Helmholtz resonator holds the cone still, so the motional impedance is
%   small. Returns v.fL, v.fH, v.fb (|Z| minimum) and v.fb_phase (where the
%   phase crosses zero going up between the peaks).

if nargin < 3, fmax = 300; end
fn = fn(:); Z = Z(:);
k = fn > 0 & fn < fmax;
fn = fn(k); Z = Z(k); Zm = abs(Z);

% the two highest local maxima
pk = find(Zm(2:end-1) > Zm(1:end-2) & Zm(2:end-1) >= Zm(3:end)) + 1;
if numel(pk) < 2, error('Fewer than two impedance peaks below %g Hz.', fmax); end
[~, s] = sort(Zm(pk), 'descend');
two = sort(pk(s(1:2)));
v.fL = fn(two(1)); v.fH = fn(two(2));

seg = two(1):two(2);
[~, i] = min(Zm(seg));
v.fb = fn(seg(i)); v.Zmin = Zm(seg(i));

ph = angle(Z(seg));
j = find(ph(1:end-1) < 0 & ph(2:end) >= 0, 1);
if isempty(j)
    v.fb_phase = NaN;
else
    v.fb_phase = interp1(ph(j:j+1), fn(seg(j:j+1)), 0);
end
end
