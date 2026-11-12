function y = lab_smooth(f, x, frac)
% LAB_SMOOTH  1/frac-octave moving average on a log-spaced grid (default 1/6 octave), NaN-safe.
if nargin < 3, frac = 6; end
f = f(:); x = x(:); lf = log2(f); y = nan(size(x));
for i = 1:numel(f)
    k = abs(lf - lf(i)) <= 1/(2*frac);
    y(i) = mean(x(k), 'omitnan');
end
end
